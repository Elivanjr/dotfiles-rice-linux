// WallpaperPicker.qml — seletor de papel de parede (Hyprland + swww)
//
// Mesmo molde do AiSidebar: abre à esquerda, sob a topbar,
// controlado por panelOpen / closeRequested().
//
// Lê ~/Imagens/hyprlandWallpapers/, mostra miniaturas em grade,
// aplica com `swww img` e (opcional) roda `matugen image` para
// regenerar Colors.qml automaticamente.
//
// Requer: swww rodando (`swww init`). Matugen é opcional.
// Duplo clique na miniatura aplica sem precisar do botão.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../theme"

PanelWindow {
  id: wp

  required property var screenRef
  screen: screenRef

  property bool panelOpen: false
  property bool atBottom: false
  property int topInset: 51
  property int bottomInset: 46
  property string nerdFont: "JetBrainsMono NF"
  property int moduleRadius: 20

  property int panelWidth: 520
  property bool pinned: false
  property int leftPad: 0     // deslocamento horizontal (ex: largura do ToolRail)

  property string wallDir: Quickshell.env("HOME") + "/Imagens/hyprlandWallpapers"

  // transição do swww: wipe | fade | grow | outer | wave | random
  property string transition: "wipe"

  // rodar matugen após aplicar (regenera Colors.qml automaticamente)
  property bool runMatugen: true

  signal closeRequested()

  // ── estado ──────────────────────────────────────────────────────
  property string currentWall:  ""   // wallpaper ativo agora (via swww query)
  property string selectedWall: ""   // clicado mas ainda não aplicado
  property bool   scanning:     false
  property bool   applying:     false
  property string statusMsg:    ""
  property bool   statusErr:    false
  property real   slide:        1

  readonly property int cols:  2
  readonly property int thumbH: 112

  ListModel { id: wallModel }

  // ── camada / foco (igual AiSidebar) ────────────────────────────
  visible: panelOpen
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  anchors { top: true; bottom: true; left: true; right: !wp.pinned }
  implicitWidth: wp.pinned ? wp.panelWidth + 16 : 0
  mask: wp.pinned ? pinRegion : null

  Region { id: pinRegion; item: card }

  WlrLayershell.layer: wp.pinned ? WlrLayer.Top : WlrLayer.Overlay
  WlrLayershell.keyboardFocus: !wp.panelOpen
    ? WlrKeyboardFocus.None
    : (wp.pinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
  WlrLayershell.namespace: "quickshell:wallpaper"

  // ── cores — matugen ─────────────────────────────────────────────
  readonly property color cBg:      Colors.md3.surface_container
  readonly property color cItem:    Colors.md3.surface_container_high
  readonly property color cItemHi:  Colors.md3.surface_container_highest
  readonly property color cText:    Colors.md3.source_color
  readonly property color cMuted:   Colors.md3.outline
  readonly property color cLine:    Colors.md3.outline_variant
  readonly property color cAccent:  Colors.md3.primary
  readonly property color cOnAccent: Colors.md3.on_primary
  readonly property color cError:   Colors.md3.error

  // ── lógica ──────────────────────────────────────────────────────
  onPanelOpenChanged: {
    if (!wp.panelOpen) return;
    slideAnim.restart();
    wp.statusMsg = "";
    wp.statusErr = false;
    wp.scan();
    wp.queryCurrentWall();
  }

  function scan() {
    if (scanProc.running) return;
    wp.scanning = true;
    wallModel.clear();
    wp.selectedWall = "";
    // find sem shell: usa bash -c pra poder usar ( -o )
    scanProc.command = [
      "bash", "-c",
      "find " + JSON.stringify(wp.wallDir)
        + " -maxdepth 1 -type f \\("
        + " -iname '*.jpg' -o -iname '*.jpeg'"
        + " -o -iname '*.png' -o -iname '*.webp'"
        + " -o -iname '*.gif'"
        + " \\) -print | sort"
    ];
    scanProc.running = true;
  }

  function parseScan(text) {
    wp.scanning = false;
    const lines = text.trim().split("\n").filter(l => l !== "");
    wallModel.clear();
    for (const p of lines) {
      wallModel.append({ wpath: p, wname: p.replace(/.*\//, "") });
    }
    if (wallModel.count === 0) {
      wp.statusMsg = "Nenhuma imagem em " + wp.wallDir + ".";
      wp.statusErr = true;
    }
  }

  function queryCurrentWall() {
    if (queryProc.running) return;
    queryProc.command = ["awww", "query"];
    queryProc.running = true;
  }

  function parseQuery(text) {
    // "HDMI-A-1: ... image: /home/.../wall.jpg, ..."
    const m = text.match(/image:\s*([^\s,\n]+)/);
    if (m) wp.currentWall = m[1].trim();
  }

  function applyWall(path) {
    const target = path || wp.selectedWall;
    if (target === "" || wp.applying) return;
    wp.applying = true;
    wp.statusMsg = "Aplicando…";
    wp.statusErr = false;
    applyProc.command = ["awww", "img", target];
    applyProc.running = true;
    applyProc.targetPath = target;
  }

  function onApplyDone(code) {
    if (code === 0) {
      wp.currentWall  = applyProc.targetPath;
      wp.selectedWall = "";
      if (wp.runMatugen) {
        wp.statusMsg = "Aplicado · regenerando cores…";
        matugenProc.command = ["matugen", "image", wp.currentWall];
        matugenProc.running = true;
      } else {
        wp.applying  = false;
        wp.statusMsg = "Aplicado com sucesso.";
      }
    } else {
      wp.applying  = false;
      wp.statusMsg = "Falha ao aplicar (código " + code + "). O awww está rodando?";
      wp.statusErr = true;
    }
  }

  function onMatugenDone(code) {
    wp.applying  = false;
    wp.statusMsg = code === 0
      ? "Aplicado · cores regeneradas."
      : "Aplicado · matugen falhou (código " + code + ").";
    wp.statusErr = code !== 0;
  }

  // ── processos ───────────────────────────────────────────────────
  Process {
    id: scanProc
    stdout: StdioCollector { onStreamFinished: wp.parseScan(this.text) }
  }

  Process {
    id: queryProc
    stdout: StdioCollector { onStreamFinished: wp.parseQuery(this.text) }
  }

  Process {
    id: applyProc
    property string targetPath: ""
    onExited: (code) => wp.onApplyDone(code)
  }

  Process {
    id: matugenProc
    onExited: (code) => wp.onMatugenDone(code)
  }

  // ── animação ────────────────────────────────────────────────────
  NumberAnimation {
    id: slideAnim
    target: wp; property: "slide"
    from: 0; to: 1; duration: 190
    easing.type: Easing.OutCubic
  }

  // ── componentes base ────────────────────────────────────────────
  component Glyph: Text {
    font.family: wp.nerdFont; font.pixelSize: 16
    color: wp.cText
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment:   Text.AlignVCenter
  }

  component Label: Text {
    font.family: wp.nerdFont; font.pixelSize: 12
    color: wp.cText; elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
  }

  component RoundBtn: Rectangle {
    id: rb
    property string glyph: ""
    property bool   active: false
    signal clicked()
    implicitWidth: 32; implicitHeight: 32; radius: width / 2
    color: rb.active
      ? (rba.containsMouse ? Qt.lighter(wp.cAccent, 1.1) : wp.cAccent)
      : (rba.containsMouse ? wp.cItemHi : wp.cItem)
    Glyph {
      anchors.centerIn: parent; text: rb.glyph; font.pixelSize: 13
      color: rb.active ? wp.cOnAccent : wp.cText
    }
    MouseArea { id: rba; anchors.fill: parent; hoverEnabled: true; onClicked: rb.clicked() }
  }

  component PillBtn: Rectangle {
    id: pb
    property string text: ""; property string glyph: ""
    property bool primary: false; property bool disabled: false
    signal clicked()
    implicitHeight: 38; implicitWidth: pbr.implicitWidth + 32; radius: height / 2
    color: pb.disabled   ? wp.cLine
         : pb.primary    ? (pba.containsMouse ? Qt.lighter(wp.cAccent,1.1) : wp.cAccent)
                         : (pba.containsMouse ? wp.cItemHi : wp.cItem)
    opacity: pb.disabled ? 0.5 : 1
    Row {
      id: pbr; anchors.centerIn: parent; spacing: 8
      Glyph { visible: pb.glyph !== ""; text: pb.glyph; font.pixelSize: 13
               color: pb.primary ? wp.cOnAccent : wp.cText }
      Label { text: pb.text; font.bold: true; color: pb.primary ? wp.cOnAccent : wp.cText }
    }
    MouseArea { id: pba; anchors.fill: parent; hoverEnabled: true
                enabled: !pb.disabled; onClicked: pb.clicked() }
  }

  component Spinner: Glyph {
    id: spn; text: "\uf110"; color: wp.cAccent
    RotationAnimator on rotation {
      from: 0; to: 360; duration: 900
      loops: Animation.Infinite; running: spn.visible
    }
  }

  // ── UI ──────────────────────────────────────────────────────────
  Item {
    id: rootItem
    anchors.fill: parent; focus: true
    Keys.onEscapePressed: wp.closeRequested()

    MouseArea { anchors.fill: parent; enabled: !wp.pinned; onClicked: wp.closeRequested() }

    Rectangle {
      id: card
      width: wp.panelWidth
      x: wp.leftPad + 8 - (1 - wp.slide) * 36
      y: wp.atBottom ? 8 : wp.topInset
      opacity: wp.slide
      height: parent.height - y - (wp.atBottom ? wp.bottomInset : 8)
      radius: Math.min(wp.moduleRadius, 28)
      color: wp.cBg; border.width: 1; border.color: wp.cLine; clip: true

      MouseArea { anchors.fill: parent }

      ColumnLayout {
        anchors.fill: parent; anchors.margins: 14; spacing: 10

        // ── cabeçalho ─────────────────────────────────────────────
        RowLayout {
          Layout.fillWidth: true; spacing: 8

          Glyph { text: "\uf03e"; color: wp.cAccent; font.pixelSize: 20 }

          Rectangle {
            Layout.fillWidth: true; implicitHeight: 32; radius: height / 2; color: wp.cItem
            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12; spacing: 8
              Label { text: "Papel de Parede"; font.bold: true; Layout.fillWidth: true }
              Spinner { visible: wp.scanning || wp.applying; font.pixelSize: 9 }
            }
          }

          RoundBtn { glyph: "\uf08d"; active: wp.pinned; onClicked: wp.pinned = !wp.pinned }
          RoundBtn { glyph: "\uf00d"; onClicked: wp.closeRequested() }
        }

        // ── status / erro ──────────────────────────────────────────
        Rectangle {
          visible: wp.statusMsg !== ""
          Layout.fillWidth: true
          implicitHeight: stRow.implicitHeight + 16
          radius: 14; color: wp.cItem
          border.width: 1; border.color: wp.statusErr ? wp.cError : wp.cLine

          RowLayout {
            id: stRow
            anchors { left: parent.left; right: parent.right
                      verticalCenter: parent.verticalCenter
                      leftMargin: 12; rightMargin: 8 }
            spacing: 8
            Label {
              text: wp.statusMsg; font.pixelSize: 11
              color: wp.statusErr ? wp.cError : wp.cMuted
              wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true
            }
            RoundBtn {
              glyph: "\uf00d"; implicitWidth: 26; implicitHeight: 26
              onClicked: { wp.statusMsg = ""; wp.statusErr = false; }
            }
          }
        }

        // ── grade de wallpapers ────────────────────────────────────
        Rectangle {
          Layout.fillWidth: true; Layout.fillHeight: true
          radius: 16; color: wp.cItem; clip: true

          Label {
            visible: wallModel.count === 0 && !wp.scanning
            anchors.centerIn: parent; text: "Nenhum wallpaper encontrado"; color: wp.cMuted
          }
          Spinner {
            visible: wp.scanning; anchors.centerIn: parent; font.pixelSize: 24
          }

          GridView {
            id: grid
            anchors.fill: parent; anchors.margins: 8
            model: wallModel; clip: true
            boundsBehavior: Flickable.StopAtBounds

            cellWidth:  Math.floor(grid.width / wp.cols)
            cellHeight: wp.thumbH + 30   // miniatura + legenda

            // scrollbar fina
            Rectangle {
              visible: grid.contentHeight > grid.height
              x: grid.width - 4
              y: grid.visibleArea.yPosition * grid.height
              width: 3
              height: Math.max(24, grid.visibleArea.heightRatio * grid.height)
              radius: 2; color: wp.cMuted; opacity: 0.45
            }

            delegate: Item {
              id: cell
              required property string wpath
              required property string wname

              width: grid.cellWidth; height: grid.cellHeight

              readonly property bool isCurrent:  cell.wpath === wp.currentWall
              readonly property bool isSelected: cell.wpath === wp.selectedWall

              Rectangle {
                anchors.fill: parent; anchors.margins: 4
                radius: 14; clip: true; color: "transparent"
                border.width: cell.isSelected ? 2 : (cell.isCurrent ? 1 : 0)
                border.color: cell.isSelected ? wp.cAccent : wp.cMuted

                // miniatura
                Image {
                  id: thumb
                  width: parent.width; height: wp.thumbH
                  source: "file://" + cell.wpath
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true; smooth: true; cache: true

                  // carregando
                  Rectangle {
                    visible: thumb.status === Image.Loading
                    anchors.fill: parent; color: wp.cItemHi
                    Spinner { anchors.centerIn: parent; font.pixelSize: 18 }
                  }
                  // erro
                  Rectangle {
                    visible: thumb.status === Image.Error
                    anchors.fill: parent; color: wp.cItemHi
                    Glyph { anchors.centerIn: parent; text: "\uf071"; color: wp.cError }
                  }

                  // overlay seleção
                  Rectangle {
                    anchors.fill: parent
                    color: cell.isSelected
                      ? Qt.rgba(wp.cAccent.r, wp.cAccent.g, wp.cAccent.b, 0.32)
                      : "transparent"

                    // ícone de status (canto superior direito)
                    Glyph {
                      visible: cell.isSelected || cell.isCurrent
                      anchors.right: parent.right; anchors.top: parent.top
                      anchors.margins: 7
                      text: cell.isSelected ? "\uf00c" : "\uf058"
                      color: cell.isSelected ? wp.cOnAccent : wp.cAccent
                      font.pixelSize: 15
                    }
                  }
                }

                // legenda (nome do arquivo)
                Rectangle {
                  width: parent.width
                  anchors.top: thumb.bottom
                  height: parent.height - wp.thumbH
                  color: cell.isCurrent
                    ? Qt.rgba(wp.cAccent.r, wp.cAccent.g, wp.cAccent.b, 0.15)
                    : "transparent"

                  Label {
                    anchors.fill: parent
                    anchors.leftMargin: 8; anchors.rightMargin: 8
                    text: cell.wname; font.pixelSize: 10
                    color: cell.isCurrent ? wp.cAccent : wp.cMuted
                    font.bold: cell.isCurrent
                    elide: Text.ElideMiddle
                    verticalAlignment: Text.AlignVCenter
                  }
                }

                MouseArea {
                  anchors.fill: parent; hoverEnabled: true
                  // clique simples: seleciona (toggle)
                  onClicked: {
                    wp.selectedWall = (wp.selectedWall === cell.wpath) ? "" : cell.wpath;
                    wp.statusMsg = "";
                  }
                  // duplo clique: aplica direto
                  onDoubleClicked: {
                    wp.selectedWall = cell.wpath;
                    wp.applyWall(cell.wpath);
                  }
                }
              }
            }
          }
        }

        // ── rodapé ────────────────────────────────────────────────
        RowLayout {
          Layout.fillWidth: true; spacing: 8

          // toggle matugen
          Rectangle {
            implicitWidth: mgRow.implicitWidth + 24; implicitHeight: 38; radius: height / 2
            color: mga.containsMouse ? wp.cItemHi : wp.cItem
            RowLayout {
              id: mgRow; anchors.centerIn: parent; spacing: 8
              Rectangle {
                width: 18; height: 18; radius: 9
                color: wp.runMatugen ? wp.cAccent : wp.cLine
                border.width: 1; border.color: wp.runMatugen ? wp.cAccent : wp.cMuted
                Glyph {
                  anchors.centerIn: parent; text: "\uf00c"
                  font.pixelSize: 9; color: wp.cOnAccent; visible: wp.runMatugen
                }
              }
              Label { text: "matugen"; font.pixelSize: 11; color: wp.cMuted }
            }
            MouseArea { id: mga; anchors.fill: parent; hoverEnabled: true
                         onClicked: wp.runMatugen = !wp.runMatugen }
          }

          PillBtn {
            Layout.fillWidth: true
            primary:  wp.selectedWall !== "" && !wp.applying
            disabled: wp.selectedWall === "" || wp.applying
            glyph: wp.applying ? "\uf110" : "\uf03e"
            text:  wp.applying        ? "Aplicando…"
                 : wp.selectedWall !== "" ? "Aplicar"
                                          : "Selecione um wallpaper"
            onClicked: wp.applyWall("")
          }

          RoundBtn { glyph: "\uf021"; onClicked: wp.scan() }
        }
      }
    }
  }
}
