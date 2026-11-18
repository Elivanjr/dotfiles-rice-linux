// core/MenuView.qml — Menu de apps do sistema

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: menuView

  visible: phone.view === "menu"

  // título: app selecionado (ou busca)
  Text {
    x: s(10)
    y: s(46) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.menu.query === ""
      ? phone.menu.selectedName
      : phone.menu.query + "_"

    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  // roda do mouse troca de linha
  MouseArea {
    x: 0
    y: s(60)
    width: lcd.width
    height: s(230)

    acceptedButtons: Qt.NoButton

    onWheel: function (w) {
      phone.menu.move(w.angleDelta.y > 0 ? -4 : 4);
    }
  }

  // grade 4x4
  Repeater {
    model:
      phone.menu.menuItems.slice(
        phone.menu.page * phone.menu.perPage,
        phone.menu.page * phone.menu.perPage + phone.menu.perPage
      )

    Item {
      id: cell

      required property var modelData
      required property int index

      readonly property int globalIndex:
        phone.menu.page * phone.menu.perPage + index

      readonly property bool isSel:
        globalIndex === phone.menu.selected

      readonly property string iconUrl:
        modelData.glyph ? "" : phone.menu.resolveIcon(modelData.icon)

      width: s(67)
      height: s(56)

      x: s(40 + (index % 4) * 67.33) - width / 2
      y: s(89 + Math.floor(index / 4) * 56.33) - height / 2

      // anel de seleção
      Rectangle {
        visible: cell.isSel
        anchors.centerIn: parent
        width: s(50)
        height: s(50)
        radius: width / 2

        color: phone.ov(0.04)
        border.color: phone.ring
        border.width: Math.max(1.5, s(2))
      }

      Item {
        anchors.centerIn: parent
        width: s(31)
        height: s(31)

        // Apps internos usam os metadados visuais do registro.
        Rectangle {
          visible: !!modelData.glyph
          anchors.fill: parent
          radius: modelData.roundIcon ? width / 2 : s(6)
          color: modelData.tileColor || phone.cTile

          Glyph {
            anchors.centerIn: parent
            width: s(modelData.glyphSize || 21)
            height: s(modelData.glyphSize || 21)
            kind: modelData.glyph || ""
            stroke: modelData.glyphColor || "white"
          }
        }

        Image {
          id: appIcon

          anchors.fill: parent
          visible: status === Image.Ready

          source: cell.iconUrl
          sourceSize.width: 64
          sourceSize.height: 64
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
        }

        // sem ícone: círculo com a inicial
        Rectangle {
          visible: !modelData.glyph && appIcon.status !== Image.Ready

          anchors.fill: parent
          radius: width / 2
          color: phone.cTile

          Text {
            anchors.centerIn: parent

            text: (modelData.name || "?").charAt(0).toUpperCase()
            color: phone.txt
            font.family: phone.fontUi
            font.bold: true
            font.pixelSize: s(15)
          }
        }
      }

      MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: phone.menu.selected = cell.globalIndex
        onClicked: phone.menu.launch(cell.modelData)
      }
    }
  }

  // bolinhas de página
  Row {
    visible: phone.menu.pageCount > 1

    x: (lcd.width - width) / 2
    y: s(292) - height / 2
    spacing: s(5)

    Repeater {
      model: phone.menu.pageCount

      Rectangle {
        required property int index

        width: s(4)
        height: s(4)
        radius: width / 2

        color: index === phone.menu.page ? phone.cDotOn : phone.cDot
      }
    }
  }

  Text {
    visible: phone.menu.menuItems.length === 0
    anchors.horizontalCenter: parent.horizontalCenter
    y: s(150)

    text: "Nenhum app encontrado"
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(14)
  }
}
