// LauncherPanel.qml — launcher nativo do Quickshell, no lugar do rofi.
//
// Substitui ~/.config/rofi/runner.sh. 3 modos:
//   DRUN   -> aplicativos instalados (via DesktopEntries, o índice nativo
//             do Quickshell — não faz parsing manual de .desktop)
//   Files  -> navegador de diretórios de verdade (não é busca fuzzy):
//             mostra o diretório atual, ".." pra subir, pastas e arquivos.
//             Ao ativar um arquivo, abre com `xdg-open` (cai no app padrão
//             do sistema pro tipo — imagem abre no visualizador padrão, etc).
//   Window -> janelas abertas no Hyprland (foca via Hyprland.dispatch)
//
// Instalação: já está em ~/.config/quickshell/topbar/LauncherPanel.qml
// (arquivos no mesmo diretório do shell.qml viram componentes automaticamente
// — é por isso que o shell.qml só precisa escrever "LauncherPanel { ... }").
//
// Atalhos: digite pra filtrar · ↑/↓ navega · Enter ativa (ou entra na pasta)
// · Backspace com busca vazia sobe um diretório (só no modo Files) · Tab
// troca de modo · Esc fecha · clique fora fecha.
//
// Ícones: usa Quickshell.iconPath(nome, true) — a variante "check", que
// devolve string vazia se o ícone não existe no tema em vez do quadrado
// roxo/preto de "textura quebrada". Quando fica vazia, cai num glifo da
// Nerd Font em vez de mostrar esse quadrado corrompido.
//
// Cores: 100% Colors.md3 (gerado pelo matugen a partir do Colors.qml).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../theme"

PanelWindow {
  id: launcher

  required property var screenRef
  property bool panelOpen: false
  signal closeRequested()

  // repassados pelo shell.qml pra combinar com o resto da topbar —
  // têm defaults sensatos caso seja usado sozinho
  property string nerdFont: "JetBrainsMono NF"
  property int barHeight: 39
  property int barMargin: 6

  screen: screenRef
  visible: panelOpen
  color: "transparent"

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.namespace: "quickshell:launcher"

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  // ---------- paleta ----------
  // Paleta visual inspirada no Rofi da referência: vidro/transparência,
  // borda discreta e destaque sólido apenas no item selecionado.
  readonly property color colCardBg: Qt.alpha(Colors.md3.surface, 0.68)
  readonly property color colRowBg: Qt.alpha(Colors.md3.surface_container, 0.34)
  readonly property color colText: Colors.md3.source_color
  readonly property color colMuted: Qt.alpha(Colors.md3.source_color, 0.72)
  readonly property color colAccent: Colors.md3.primary

  // ---------- ícones sem quadrado roxo/preto quebrado ----------
  // iconPath(nome, true) -> "" se o ícone não existir no tema (em vez da
  // textura de "faltando"). Quando vem vazio, o delegate cai pro glyph.
  function resolveIcon(name) {
    if (!name)
      return "";
    return Quickshell.iconPath(name, true);
  }

  // ---------- estado ----------
  property string mode: "drun" // drun | files | window
  property string query: ""
  property var results: []

  readonly property var modes: [
    { id: "drun", label: "Apps", icon: "\uf00a" },
    { id: "files", label: "Arquivos", icon: "\uf07c" },
    { id: "window", label: "Janelas", icon: "\uf108" }
  ]

  readonly property var placeholders: ({
    drun: "Pesquisar aplicativos...",
    files: "Filtrar nesta pasta...",
    window: "Pesquisar janelas abertas..."
  })

  function closeLauncher() {
    launcher.closeRequested();
  }

  function resetState() {
    query = "";
    searchInput.text = "";
    resultsList.currentIndex = 0;
  }

  onPanelOpenChanged: {
    if (panelOpen) {
      resetState();
      if (mode === "files" && dirEntries.length === 0)
        loadDirectory(currentDir);
      recomputeResults();
      searchInput.forceActiveFocus();
    }
  }

  function switchMode(newMode) {
    mode = newMode;
    resultsList.currentIndex = 0;
    if (mode === "files" && dirEntries.length === 0)
      loadDirectory(currentDir);
    recomputeResults();
  }

  // =====================================================================
  // DRUN — aplicativos (DesktopEntries é o índice nativo do Quickshell,
  // já ignora Hidden/NoDisplay sozinho)
  // =====================================================================
  readonly property string drunFallbackGlyph: "\uf085" // fa-cogs (app genérico)

  function drunResults(q) {
    const needle = q.toLowerCase();
    let list = DesktopEntries.applications.values.filter((e) => {
      if (!needle) return true;
      return (e.name || "").toLowerCase().indexOf(needle) !== -1
        || (e.genericName || "").toLowerCase().indexOf(needle) !== -1
        || (e.comment || "").toLowerCase().indexOf(needle) !== -1;
    });

    list.sort((a, b) => (a.name || "").localeCompare(b.name || ""));

    return list.map((e) => ({
      label: e.name || e.id,
      iconSource: resolveIcon(e.icon),
      glyph: drunFallbackGlyph,
      activate: () => {
        e.execute();
        closeLauncher();
      }
    }));
  }

  // =====================================================================
  // WINDOW — janelas abertas via Hyprland
  // =====================================================================
  readonly property string windowFallbackGlyph: "\uf2d0" // fa-window-restore

  function iconForAppId(appId) {
    const entry = appId ? DesktopEntries.heuristicLookup(appId) : null;
    const iconName = entry && entry.icon ? entry.icon : appId;
    return resolveIcon(iconName);
  }

  function windowResults(q) {
    const needle = q.toLowerCase();
    let list = Hyprland.toplevels.values.filter((t) => {
      const appId = (t.wayland && t.wayland.appId) || "";
      if (!needle) return true;
      return (t.title || "").toLowerCase().indexOf(needle) !== -1
        || appId.toLowerCase().indexOf(needle) !== -1;
    });

    return list.map((t) => {
      const appId = (t.wayland && t.wayland.appId) || "";
      return {
        label: t.title || appId || "(sem título)",
        iconSource: iconForAppId(appId),
        glyph: windowFallbackGlyph,
        activate: () => {
          // No Hyprland em modo Lua, não usamos a sintaxe textual antiga
          // de Hyprland.dispatch("workspace ..."). O próprio objeto de
          // workspace sabe ativar o workspace corretamente.
          //
          // Para a janela, o Toplevel Wayland também possui activate(),
          // que é a API nativa do Quickshell para pedir foco na janela.
          const workspace = t.workspace;
          const toplevel = t.wayland;

          closeLauncher();

          Qt.callLater(() => {
            if (workspace)
              workspace.activate();

            Qt.callLater(() => {
              if (toplevel)
                toplevel.activate();
            });
          });
        }
      };
    });
  }

  // =====================================================================
  // FILES — navegador de diretório de verdade (não é busca recursiva)
  // =====================================================================
  readonly property string folderGlyph: "\uf07b" // fa-folder
  readonly property string fileGlyph: "\uf15b" // fa-file
  readonly property string upGlyph: "\uf148" // fa-level-up (a entrada "..")

  property string currentDir: Quickshell.env("HOME")
  property var dirEntries: [] // [{name, isDir}], sem a ".."

  Process {
    id: dirProc
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = this.text.split("\n").filter((l) => l.length > 0);
        let entries = lines.map((line) => {
          const tab = line.indexOf("\t");
          const kind = line.slice(0, tab);
          const name = line.slice(tab + 1);
          return { name: name, isDir: kind === "d" };
        });

        entries.sort((a, b) => {
          if (a.isDir !== b.isDir)
            return a.isDir ? -1 : 1;
          return a.name.localeCompare(b.name);
        });

        launcher.dirEntries = entries;
        launcher.recomputeResults();
      }
    }
  }

  function loadDirectory(path) {
    dirProc.command = [
      "bash", "-c",
      "find \"$1\" -maxdepth 1 -mindepth 1 -printf '%y\\t%f\\n' 2>/dev/null",
      "bash",
      path
    ];
    dirProc.running = true;
  }

  function navigateTo(path) {
    currentDir = path;
    query = "";
    searchInput.text = "";
    resultsList.currentIndex = 0;
    loadDirectory(path);
  }

  function navigateUp() {
    const parts = currentDir.split("/").filter((p) => p.length > 0);
    parts.pop();
    navigateTo("/" + parts.join("/"));
  }

  function filesResults(q) {
    const needle = q.toLowerCase();
    const parentPath = currentDir === "/" ? null : "..";

    let items = [];

    if (parentPath !== null) {
      items.push({
        label: "..",
        iconSource: "",
        glyph: upGlyph,
        activate: () => launcher.navigateUp()
      });
    }

    const filtered = dirEntries.filter((entry) =>
      !needle || entry.name.toLowerCase().indexOf(needle) !== -1
    );

    for (const entry of filtered) {
      const fullPath = launcher.currentDir.replace(/\/$/, "") + "/" + entry.name;

      if (entry.isDir) {
        items.push({
          label: entry.name + "/",
          iconSource: resolveIcon("folder"),
          glyph: folderGlyph,
          activate: () => launcher.navigateTo(fullPath)
        });
      } else {
        items.push({
          label: entry.name,
          iconSource: resolveIcon(mimeIconGuess(entry.name)),
          glyph: fileGlyph,
          activate: () => {
            Quickshell.execDetached({ command: ["xdg-open", fullPath] });
            launcher.closeLauncher();
          }
        });
      }
    }

    return items;
  }

  // chute rápido de ícone genérico por extensão — sem chamar `file`/xdg-mime
  // por item (custaria um processo por linha da lista)
  function mimeIconGuess(name) {
    const ext = name.includes(".") ? name.split(".").pop().toLowerCase() : "";

    const images = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif"];
    const videos = ["mp4", "mkv", "webm", "mov", "avi"];
    const audio = ["mp3", "flac", "wav", "ogg", "m4a"];
    const archives = ["zip", "tar", "gz", "xz", "7z", "rar"];
    const text = ["txt", "md", "qml", "js", "ts", "py", "json", "conf", "sh", "yml", "yaml", "css", "html"];

    if (images.includes(ext)) return "image-x-generic";
    if (videos.includes(ext)) return "video-x-generic";
    if (audio.includes(ext)) return "audio-x-generic";
    if (archives.includes(ext)) return "package-x-generic";
    if (text.includes(ext)) return "text-x-generic";

    return "text-x-generic";
  }

  // =====================================================================
  // roteamento de resultados por modo
  // =====================================================================
  function recomputeResults() {
    switch (mode) {
      case "drun":
        results = drunResults(query);
        break;
      case "window":
        results = windowResults(query);
        break;
      case "files":
        results = filesResults(query);
        break;
    }

    if (resultsList.currentIndex >= results.length)
      resultsList.currentIndex = Math.max(0, results.length - 1);
  }

  function activateCurrent() {
    const item = results[resultsList.currentIndex];
    if (item)
      item.activate();
  }

  // ---------- clique fora fecha ----------
  MouseArea {
    anchors.fill: parent
    onClicked: launcher.closeLauncher()
  }

  Rectangle {
    id: card

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter

    width: 450
    implicitHeight: Math.min(parent.height - 36, 570)
    height: implicitHeight
    radius: 13
    color: launcher.colCardBg
    border.width: 1
    border.color: Qt.alpha(launcher.colAccent, 0.70)

    // segura o clique pra não fechar o painel ao interagir com o card
    MouseArea {
      anchors.fill: parent
      onClicked: (mouse) => mouse.accepted = true
    }

    ColumnLayout {
      id: contentColumn

      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        leftMargin: 20
        rightMargin: 20
        topMargin: 18
        bottomMargin: 16
      }

      spacing: 10

      // ---- barra de busca ----
      Rectangle {
        Layout.fillWidth: true
        height: 36
        radius: 0
        color: "transparent"

        RowLayout {
          anchors {
            fill: parent
            leftMargin: 2
            rightMargin: 2
          }
          spacing: 9

          Text {
            text: "\uf002" // fa-search
            font.family: launcher.nerdFont
            font.pixelSize: 14
            color: launcher.colMuted
          }

          TextInput {
            id: searchInput

            Layout.fillWidth: true
            color: launcher.colText
            selectionColor: launcher.colAccent
            font.family: launcher.nerdFont
            font.pixelSize: 13
            clip: true

            Keys.onPressed: (event) => {
              if (event.key === Qt.Key_Escape) {
                launcher.closeLauncher();
                event.accepted = true;
              } else if (event.key === Qt.Key_Down) {
                resultsList.currentIndex = Math.min(
                  resultsList.currentIndex + 1,
                  launcher.results.length - 1
                );
                event.accepted = true;
              } else if (event.key === Qt.Key_Up) {
                resultsList.currentIndex = Math.max(resultsList.currentIndex - 1, 0);
                event.accepted = true;
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                launcher.activateCurrent();
                event.accepted = true;
              } else if (event.key === Qt.Key_Backspace && searchInput.text.length === 0
                  && launcher.mode === "files" && launcher.currentDir !== "/") {
                launcher.navigateUp();
                event.accepted = true;
              } else if (event.key === Qt.Key_Tab) {
                const order = ["drun", "files", "window"];
                const next = order[(order.indexOf(launcher.mode) + 1) % order.length];
                launcher.switchMode(next);
                event.accepted = true;
              } else if (event.key === Qt.Key_1) {
                launcher.switchMode("drun");
                event.accepted = true;
              } else if (event.key === Qt.Key_2) {
                launcher.switchMode("files");
                event.accepted = true;
              } else if (event.key === Qt.Key_3) {
                launcher.switchMode("window");
                event.accepted = true;
              }
            }

            onTextChanged: {
              launcher.query = text;
              resultsList.currentIndex = 0;
              launcher.recomputeResults();
            }

            Text {
              visible: searchInput.text.length === 0
              text: "Search..."
              color: Qt.alpha(launcher.colText, 0.72)
              font: searchInput.font
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }

      // ---- abas de modo ----
      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        spacing: 12

        Repeater {
          model: launcher.modes

          Rectangle {
            required property var modelData

            Layout.fillWidth: true
            Layout.minimumWidth: 58
            height: 42
            radius: 8
            color: launcher.mode === modelData.id
              ? launcher.colAccent
              : "transparent"

            Text {
              anchors.centerIn: parent
              text: modelData.icon
              font.family: launcher.nerdFont
              font.pixelSize: 15
              color: launcher.mode === modelData.id
                ? Colors.md3.on_primary
                : Qt.alpha(launcher.colText, 0.82)
            }

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                launcher.switchMode(modelData.id);
                searchInput.forceActiveFocus();
              }
            }
          }
        }
      }

      // ---- diretório atual (só no modo Files) ----
      Text {
        visible: false
        Layout.fillWidth: true
        text: "Diretório atual: " + launcher.currentDir
        elide: Text.ElideMiddle
        color: launcher.colMuted
        font.family: launcher.nerdFont
        font.pixelSize: 11
      }

      // ---- lista de resultados ----
      ListView {
        id: resultsList

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(
          Math.max(launcher.results.length, 1) * 50,
          410
        )

        clip: true
        spacing: 1
        model: launcher.results
        currentIndex: 0

        // scroll acompanha a seleção feita via teclado
        highlightMoveDuration: 80
        onCurrentIndexChanged: resultsList.positionViewAtIndex(
          resultsList.currentIndex, ListView.Contain
        )

        delegate: Rectangle {
          id: row

          required property var modelData
          required property int index

          width: resultsList.width
          height: 48
          radius: 9
          color: index === resultsList.currentIndex
            ? launcher.colAccent
            : "transparent"

          RowLayout {
            anchors {
              fill: parent
              leftMargin: 10
              rightMargin: 10
            }
            spacing: 15

            IconImage {
              visible: !!row.modelData.iconSource
              source: row.modelData.iconSource || ""
              implicitSize: 26
              Layout.preferredWidth: 26
              Layout.preferredHeight: 26
            }

            Text {
              visible: !row.modelData.iconSource
              text: row.modelData.glyph || ""
              font.family: launcher.nerdFont
              font.pixelSize: 17
              color: index === resultsList.currentIndex
                ? Colors.md3.on_primary
                : launcher.colText
              Layout.preferredWidth: 26
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              Layout.fillWidth: true
              text: row.modelData.label
              elide: Text.ElideRight
              font.family: launcher.nerdFont
              font.pixelSize: 14
              color: index === resultsList.currentIndex
                ? Colors.md3.on_primary
                : launcher.colText
            }
          }

          MouseArea {
            anchors.fill: parent
            onClicked: {
              resultsList.currentIndex = row.index;
              launcher.activateCurrent();
            }
          }
        }
      }

      Text {
        visible: launcher.results.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        horizontalAlignment: Text.AlignHCenter
        text: "Nenhum resultado"
        color: launcher.colMuted
        font.family: launcher.nerdFont
        font.pixelSize: 12
      }
    }
  }
}
