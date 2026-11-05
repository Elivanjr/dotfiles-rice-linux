// ToolRail.qml — barra de navegação lateral
//
// Sempre visível (WlrLayer.Top), abaixo da topbar.
// Colapsa em ícones ou expande com rótulos, igual ao navigation rail
// do Material 3. Emite toggle(tool) para abrir/fechar cada painel.
//
// Coloca em modules/tools/ToolRail.qml
// Import do tema: ../../theme

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../theme"

PanelWindow {
  id: rail

  required property var screenRef
  screen: screenRef

  property bool atBottom: false
  property int topInset: 51
  property int bottomInset: 46
  property string nerdFont: "JetBrainsMono NF"
  property int moduleRadius: 20

  // painel ativo no momento: "ssh" | "ai" | "wall" | ""
  property string active: ""

  // largura do card visível (usada pelos painéis como leftPad)
  readonly property int railWidth: Math.round(rail.currentW)

  signal toggle(string tool)

  // ── largura animada ──────────────────────────────────────────
  property real currentW: wMin

  readonly property int wMin: 52    // colapsado: só ícones
  readonly property int wMax: 196   // expandido: ícones + rótulos
  property bool expanded: false

  onExpandedChanged: currentW = expanded ? wMax : wMin

  Behavior on currentW {
    NumberAnimation { duration: 190; easing.type: Easing.OutCubic }
  }

  // ── camada ───────────────────────────────────────────────────
  visible: true
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  anchors { top: true; bottom: true; left: true }
  implicitWidth: rail.railWidth + 8

  // Quando um painel está aberto, o mask se reduz ao card do rail.
  // Assim, cliques fora do card caem no painel (que fecha ao ser clicado).
  // Quando nenhum painel está aberto, a janela inteira recebe eventos.
  mask: rail.active !== "" ? railMask : null
  Region { id: railMask; item: railCard }

  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.namespace: "quickshell:toolrail"

  // ── cores ─────────────────────────────────────────────────────
  readonly property color cBg:       Colors.md3.surface_container
  readonly property color cItem:     Colors.md3.surface_container_high
  readonly property color cItemHi:   Colors.md3.surface_container_highest
  readonly property color cText:     Colors.md3.source_color
  readonly property color cMuted:    Colors.md3.outline
  readonly property color cLine:     Colors.md3.outline_variant
  readonly property color cAccent:   Colors.md3.primary
  readonly property color cOnAccent: Colors.md3.on_primary

  // ── card ──────────────────────────────────────────────────────
  Rectangle {
    id: railCard
    x: 8
    y: rail.atBottom ? 8 : rail.topInset
    width: rail.railWidth - 4
    height: parent.height - y - (rail.atBottom ? rail.bottomInset : 8)
    radius: Math.min(rail.moduleRadius, 24)
    color: rail.cBg
    border.width: 1; border.color: rail.cLine
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 6
      spacing: 2

      // ── hamburger ─────────────────────────────────────────────
      NavBtn {
        glyph: "\uf0c9"           // bars
        label: "Ferramentas"
        isHeader: true
        isOn: rail.expanded
        onTriggered: rail.expanded = !rail.expanded
      }

      Rectangle {
        Layout.fillWidth: true; height: 1
        color: rail.cLine; opacity: 0.5
        Layout.topMargin: 2; Layout.bottomMargin: 2
      }

      // ── ferramentas ───────────────────────────────────────────
      NavBtn {
        glyph: "\uf120"           // terminal
        label: "SSH"
        isOn: rail.active === "ssh"
        onTriggered: rail.toggle("ssh")
      }

      NavBtn {
        glyph: "\uf544"           // robot
        label: "Chat IA"
        isOn: rail.active === "ai"
        onTriggered: rail.toggle("ai")
      }

      NavBtn {
        glyph: "\uf03e"           // image
        label: "Wallpaper"
        isOn: rail.active === "wall"
        onTriggered: rail.toggle("wall")
      }

      Item { Layout.fillHeight: true }
    }
  }

  // ── botão de navegação ────────────────────────────────────────
  component NavBtn: Rectangle {
    id: nb

    property string glyph: ""
    property string label: ""
    property bool isOn: false
    property bool isHeader: false   // hamburger não usa a cor de destaque

    signal triggered()

    Layout.fillWidth: true
    implicitHeight: 40
    radius: height / 2

    color: (!nb.isHeader && nb.isOn)
      ? rail.cAccent
      : (nba.containsMouse ? rail.cItemHi : "transparent")

    Behavior on color { ColorAnimation { duration: 130 } }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 8
      spacing: 10

      // ícone
      Text {
        id: nbIcon
        font.family: rail.nerdFont
        font.pixelSize: 15
        text: nb.glyph
        color: (!nb.isHeader && nb.isOn) ? rail.cOnAccent
             : (nba.containsMouse ? rail.cText : rail.cMuted)
        Layout.preferredWidth: 18
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Behavior on color { ColorAnimation { duration: 130 } }
      }

      // rótulo — aparece com fade enquanto o rail expande
      Text {
        font.family: rail.nerdFont
        font.pixelSize: 12
        font.weight: (!nb.isHeader && nb.isOn) ? Font.Bold : Font.Normal
        text: nb.label
        color: (!nb.isHeader && nb.isOn) ? rail.cOnAccent : rail.cText
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        Layout.fillWidth: true
        // fade proporcional à expansão
        opacity: Math.max(0, (rail.currentW - rail.wMin - 12) / (rail.wMax - rail.wMin))
        visible: opacity > 0.01
        Behavior on color { ColorAnimation { duration: 130 } }
      }
    }

    MouseArea {
      id: nba
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: nb.triggered()
    }
  }
}
