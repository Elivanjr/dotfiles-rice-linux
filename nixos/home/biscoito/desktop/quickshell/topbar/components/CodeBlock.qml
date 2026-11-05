// CodeBlock.qml — bloco de código copiável, sem dependência de WebEngine.
import QtQuick
import QtQuick.Controls
import Quickshell

Rectangle {
  id: root

  property string code: ""
  property string language: "código"
  property color textColor: "#e6e1e5"
  property color mutedColor: "#938f99"
  property color blockColor: "#211f26"
  property color borderColor: "#49454f"
  property color accentColor: "#d0bcff"
  property string fontFamily: "JetBrainsMono NF"
  property int fontPixelSize: 13

  readonly property int horizontalPadding: 12
  readonly property int verticalPadding: 10

  width: 400
  implicitHeight: header.implicitHeight + codeViewport.height + verticalPadding
  radius: 10
  color: blockColor
  border.width: 1
  border.color: borderColor

  Column {
    anchors.fill: parent
    anchors.margins: 1
    spacing: 0

    Rectangle {
      id: header
      width: parent.width
      height: 30
      radius: 9
      color: Qt.darker(root.blockColor, 1.12)

      Text {
        anchors.left: parent.left
        anchors.leftMargin: root.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 90
        text: root.language.toUpperCase()
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: 10
        elide: Text.ElideRight
      }

      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 66
        height: 24
        radius: 6
        color: copyArea.containsMouse ? Qt.darker(root.accentColor, 1.08) : "transparent"

        Row {
          anchors.centerIn: parent
          spacing: 5

          Text {
            text: "\uf0c5"
            color: root.accentColor
            font.family: root.fontFamily
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: "Copiar"
            color: root.accentColor
            font.family: root.fontFamily
            font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        MouseArea {
          id: copyArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Quickshell.execDetached(["wl-copy", root.code])
        }
      }
    }

    Flickable {
      id: codeViewport
      width: parent.width
      height: Math.min(260, Math.max(38, codeEdit.contentHeight + root.verticalPadding))
      contentWidth: Math.max(width, codeEdit.implicitWidth + root.horizontalPadding * 2)
      contentHeight: Math.max(height, codeEdit.contentHeight + root.verticalPadding)
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      TextEdit {
        id: codeEdit
        x: root.horizontalPadding
        y: root.verticalPadding / 2
        text: root.code
        textFormat: TextEdit.PlainText
        readOnly: true
        selectByMouse: true
        wrapMode: TextEdit.NoWrap
        color: root.textColor
        selectionColor: root.accentColor
        selectedTextColor: root.blockColor
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        width: Math.max(codeViewport.width - root.horizontalPadding * 2, implicitWidth)
        height: contentHeight
      }

      ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    }
  }
}
