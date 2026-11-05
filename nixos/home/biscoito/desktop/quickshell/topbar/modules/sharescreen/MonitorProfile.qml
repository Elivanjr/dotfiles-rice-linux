// modules/sharescreen/MonitorProfile.qml
//
// Seletor de perfil de monitor externo (protótipo).
//
// Fluxo:
//   1. Hyprland.rawEvent traz "monitoradded" / "monitorremoved" (socket2).
//   2. Um debounce espera o monitor "assentar" e roda `hyprctl -j monitors all`
//      para pegar nomes e resoluções reais (nada é presumido).
//   3. Se for um monitor externo (HDMI por padrão), abre a janela com 3 opções:
//        Trabalho -> estende (externo à direita do notebook)
//        Resenha  -> espelha a tela do notebook no externo
//        Manter   -> não faz nada
//   4. Aplica com `hyprctl eval 'hl.monitor({...})'`, a mesma sintaxe Lua das
//      funções espelharTela/unirTela do .zshrc — só em runtime, nada é
//      gravado em arquivo. Um reload da config do Hyprland (ou
//      `ipc call monitorprofile revert`) volta ao estado anterior.
//
// ATENÇÃO: não rode este arquivo direto com `qs -p modules/sharescreen/MonitorProfile.qml`.
// Com -p o "root" do shell vira a pasta do arquivo, o Quickshell não gera o
// qmldir do singleton ../../theme/Colors.qml e Theme.Colors.md3 fica undefined.
// Rode `qs -c topbar` (shell.qml já instancia este módulo) ou, para testar só
// ele, `qs -p MonitorTest.qml` a partir da raiz do topbar.
//
// IPC (para testar sem plugar/desplugar cabo):
//   quickshell -c topbar ipc call monitorprofile prompt
//   quickshell -c topbar ipc call monitorprofile revert
//   quickshell -c topbar ipc call monitorprofile close

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../theme" as Theme

Scope {
  id: mp

  // ---------- configuráveis (shell.qml repassa fonte e raio) ----------
  property string nerdFont: "JetBrainsMono NF"
  property int moduleRadius: 20
  // true: só reage a portas HDMI-*. false: qualquer saída que não seja a interna.
  property bool onlyHdmi: true
  readonly property var internalRe: /^(eDP|LVDS|DSI)/i

  // ---------- estado ----------
  property bool panelOpen: false
  property string targetName: ""       // monitor externo em questão
  property string pendingName: ""      // nome vindo do evento (vazio = "qualquer externo")
  property var snapshot: []            // leitura mais recente do hyprctl
  property var baseline: []            // estado de referência, tirado ao detectar
  property bool busy: false            // ignora eventos enquanto aplica
  property string lastPromptName: ""
  property double lastPromptMs: 0

  readonly property var targetScreen: {
    for (const s of Quickshell.screens) {
      if (mp.internalRe.test(s.name)) return s;
    }
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
  }

  // ---------- helpers ----------
  function isExternal(m) {
    if (mp.internalRe.test(m.name)) return false;
    return mp.onlyHdmi ? /^HDMI/i.test(m.name) : true;
  }

  function modeStr(m) {
    return m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2);
  }

  // JSON.stringify gera uma string válida também em Lua
  function luaStr(s) {
    return JSON.stringify(String(s));
  }

  // monta um hl.monitor({...}) na mesma sintaxe das funções
  // espelharTela / unirTela do .zshrc
  function luaMonitor(o) {
    let t = "hl.monitor({ output = " + luaStr(o.output) +
            ", mode = " + luaStr(o.mode) +
            ", position = " + luaStr(o.position) +
            ", scale = " + Number(o.scale);
    if (o.mirror) t += ", mirror = " + luaStr(o.mirror);
    return t + " })";
  }

  // estado lido do hyprctl -> hl.monitor equivalente (usado para reverter)
  function baselineLua(m) {
    return mp.luaMonitor({
      output: m.name,
      mode: mp.modeStr(m),
      position: m.x + "x" + m.y,
      scale: m.scale,
      mirror: (m.mirrorOf && m.mirrorOf !== "none") ? m.mirrorOf : ""
    });
  }

  // igual ao `hyprctl eval '...'` do .zshrc
  function runLua(chunks) {
    if (chunks.length === 0) return;
    const code = chunks.join("\n");
    console.log("[monitorprofile] hyprctl eval:", code);
    Quickshell.execDetached(["hyprctl", "eval", code]);
  }

  function closePanel() {
    mp.panelOpen = false;
    mp.targetName = "";
  }

  function targetMonitor() {
    return mp.snapshot.find(m => m.name === mp.targetName);
  }

  function internalMonitor() {
    return mp.snapshot.find(m => mp.internalRe.test(m.name) && !m.disabled);
  }

  // ---------- aplicar perfis ----------
  function applyProfile(profile) {
    const ext = mp.targetMonitor();
    const int_ = mp.internalMonitor();

    // o monitor pode ter sumido entre a pergunta e o clique
    if (!ext || !int_) {
      console.warn("[monitorprofile] monitor sumiu antes de aplicar; nada feito");
      mp.closePanel();
      return;
    }

    mp.busy = true;
    busyTimer.restart();

    if (profile === "work") {
      // = unirTela: externo à direita do notebook. No .zshrc a posição é
      // "1366x0" fixa; aqui vem de largura / escala da tela interna real.
      const logicalW = Math.round(int_.width / int_.scale);
      mp.runLua([
        mp.luaMonitor({
          output: ext.name,
          mode: "preferred",
          position: (int_.x + logicalW) + "x" + int_.y,
          scale: 1
        })
      ]);
    } else if (profile === "mirror") {
      // = espelharTela (opção 2): espelha a interna no externo, sem mexer
      // em bordas/gaps/rounding
      mp.runLua([
        mp.luaMonitor({
          output: ext.name,
          mode: "preferred",
          position: "0x0",
          scale: 1,
          mirror: int_.name
        })
      ]);
    }

    mp.closePanel();
  }

  function revert() {
    if (mp.baseline.length === 0) return;
    mp.busy = true;
    busyTimer.restart();
    // monitores desativados ficam de fora: este módulo nunca desativa nada
    mp.runLua(mp.baseline.filter(m => !m.disabled).map(m => mp.baselineLua(m)));
  }

  // ---------- detecção ----------
  function handleDetected(list) {
    mp.snapshot = list;

    const int_ = mp.internalMonitor();
    if (!int_) {
      console.warn("[monitorprofile] tela interna não encontrada/ativa; ignorando");
      return;
    }

    let ext = null;
    if (mp.pendingName !== "") {
      ext = list.find(m => m.name === mp.pendingName && !m.disabled);
    } else {
      ext = list.find(m => mp.isExternal(m) && !m.disabled);
    }

    if (!ext || !mp.isExternal(ext)) return;
    if (mp.panelOpen) return; // já tem janela aberta: não duplica

    // HDMI "piscando" (re-handshake) dispara vários eventos seguidos
    if (ext.name === mp.lastPromptName && Date.now() - mp.lastPromptMs < 3000) return;

    mp.lastPromptName = ext.name;
    mp.lastPromptMs = Date.now();
    mp.baseline = list.slice();
    mp.targetName = ext.name;
    mp.panelOpen = true;
  }

  function handleRemoved(name) {
    if (mp.pendingName === name) {
      mp.pendingName = "";
      detectDebounce.stop();
    }
    if (mp.targetName === name) {
      // o monitor da pergunta foi desplugado: fecha a janela sem aplicar nada
      mp.closePanel();
    }
    // o Hyprland já realoca janelas/workspaces sozinho; não mexemos em nada
    console.log("[monitorprofile] monitor removido:", name);
  }

  // ---------- eventos nativos do Hyprland ----------
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "monitoradded") {
        if (mp.busy) return;
        mp.pendingName = event.data.trim();
        detectDebounce.restart();
      } else if (event.name === "monitorremoved") {
        mp.handleRemoved(event.data.trim());
      }
    }
  }

  Timer {
    id: detectDebounce
    interval: 700
    onTriggered: monitorsProc.running = true
  }

  // janela em que eventos gerados pela própria aplicação são ignorados
  Timer {
    id: busyTimer
    interval: 2500
    onTriggered: mp.busy = false
  }

  Process {
    id: monitorsProc
    command: ["hyprctl", "-j", "monitors", "all"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          mp.handleDetected(JSON.parse(this.text));
        } catch (e) {
          console.warn("[monitorprofile] falha ao ler hyprctl:", e);
        }
      }
    }
  }

  IpcHandler {
    target: "monitorprofile"

    function prompt(): void {
      mp.pendingName = "";
      mp.lastPromptMs = 0;
      monitorsProc.running = true;
    }

    function revert(): void {
      mp.revert();
    }

    function close(): void {
      mp.closePanel();
    }
  }

  // ---------- botão do diálogo ----------
  component ChoiceButton: Rectangle {
    id: btn

    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property string hint: ""
    signal activated()

    Layout.fillWidth: true
    implicitHeight: 58
    radius: Math.min(mp.moduleRadius, height / 2)
    color: Theme.Colors.md3.surface_container
    border.width: 2
    border.color: area.containsMouse ? Theme.Colors.md3.primary : Theme.Colors.md3.outline

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 18
      anchors.rightMargin: 18
      spacing: 14

      Text {
        text: btn.glyph
        color: Theme.Colors.md3.primary
        font.family: mp.nerdFont
        font.pixelSize: 22
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
          text: btn.title
          color: Theme.Colors.md3.source_color
          font.family: mp.nerdFont
          font.pixelSize: 14
          font.bold: true
        }
        Text {
          text: btn.subtitle
          color: Theme.Colors.md3.outline
          font.family: mp.nerdFont
          font.pixelSize: 11
        }
      }

      Text {
        text: btn.hint
        color: Theme.Colors.md3.outline
        font.family: mp.nerdFont
        font.pixelSize: 11
      }
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.activated()
    }
  }

  // ---------- janela ----------
  PanelWindow {
    id: win

    screen: mp.targetScreen
    visible: mp.panelOpen && mp.targetScreen !== null

    implicitWidth: 460
    implicitHeight: content.implicitHeight + 40
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "monitor-profile"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onVisibleChanged: if (visible) keys.forceActiveFocus()

    FocusScope {
      id: keys
      anchors.fill: parent
      focus: true

      Keys.onPressed: (event) => {
        if (event.key === Qt.Key_1) mp.applyProfile("work");
        else if (event.key === Qt.Key_2) mp.applyProfile("mirror");
        else if (event.key === Qt.Key_3 || event.key === Qt.Key_Escape) mp.closePanel();
      }

      Rectangle {
        anchors.fill: parent
        radius: mp.moduleRadius
        color: Theme.Colors.md3.surface_container
        border.width: 2
        border.color: Theme.Colors.md3.outline

        ColumnLayout {
          id: content
          anchors.fill: parent
          anchors.margins: 20
          spacing: 10

          Text {
            text: "\uf108  Monitor externo detectado"
            color: Theme.Colors.md3.source_color
            font.family: mp.nerdFont
            font.pixelSize: 16
            font.bold: true
          }

          Text {
            readonly property var m: mp.targetMonitor()
            text: m ? (m.name + "  ·  " + mp.modeStr(m).replace("@", " @ ") + " Hz") : mp.targetName
            color: Theme.Colors.md3.outline
            font.family: mp.nerdFont
            font.pixelSize: 11
            Layout.bottomMargin: 6
          }

          ChoiceButton {
            glyph: "\uf108"
            title: "Trabalho"
            subtitle: "Estender a área de trabalho entre as telas"
            hint: "1"
            onActivated: mp.applyProfile("work")
          }

          ChoiceButton {
            glyph: "\uf24d"
            title: "Resenha"
            subtitle: "Espelhar a tela do notebook no monitor"
            hint: "2"
            onActivated: mp.applyProfile("mirror")
          }

          ChoiceButton {
            glyph: "\uf00d"
            title: "Manter como está"
            subtitle: "Não alterar nada"
            hint: "3 / Esc"
            onActivated: mp.closePanel()
          }
        }
      }
    }
  }
}
