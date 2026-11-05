// views/FilesView.qml — VISÃO 5 — MEUS ARQUIVOS

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: filesView

  visible: phone.view === "files"

  // nome da pasta atual
  Text {
    x: s(10)
    y: s(46) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.files.filesPick
      ? (phone.files.filesPickUpload ? "Enviar arquivo" : (phone.files.filesPickAi ? "Anexar arquivo" : "Escolher foto"))
      : phone.files.folderTitle(phone.files.filesDir)
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  // caminho completo
  Text {
    x: s(10)
    y: s(66) - height / 2
    width: s(260)

    elide: Text.ElideLeft

    text: phone.files.displayPath(phone.files.filesDir)
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(11)
  }

  ListView {
    id: filesList

    // avisa a lógica qual é este item (usado para rolar)
    Binding { target: phone.files; property: "filesListRef"; value: filesList }

    x: s(8)
    y: s(78)
    width: s(264)
    height: s(218)

    clip: true
    boundsBehavior: Flickable.StopAtBounds

    model: phone.files.fileEntries

    delegate: Item {
      id: frow

      required property var modelData
      required property int index

      readonly property bool isSel: index === phone.files.filesSelected

      width: filesList.width
      height: s(26)

      Rectangle {
        visible: frow.isSel
        anchors.fill: parent
        radius: s(4)
        color: phone.cSel
      }

      Glyph {
        x: s(8)
        y: (parent.height - height) / 2
        width: s(16)
        height: s(16)

        kind: frow.modelData.dir ? "folder" : "file"
        stroke: frow.modelData.dir ? "#e8c25a" : phone.cIcon
      }

      Text {
        x: s(32)
        width: parent.width - s(32) - s(62)
        anchors.verticalCenter: parent.verticalCenter

        elide: Text.ElideMiddle

        text: frow.modelData.name
        color: phone.txt
        font.family: phone.fontUi
        font.pixelSize: s(13)
      }

      Text {
        x: parent.width - width - s(8)
        anchors.verticalCenter: parent.verticalCenter

        text:
          frow.modelData.up
            ? ""
            : (frow.modelData.dir
                ? "\u203A"
                : phone.files.fmtSize(frow.modelData.size))

        color: phone.txtMuted
        font.family: phone.fontUi
        font.pixelSize: s(11)
      }

      MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: phone.files.filesSelected = frow.index
        onClicked: phone.files.openEntry(frow.modelData)
      }
    }
  }

  Text {
    visible:
      phone.files.fileEntries.length === (phone.files.filesDir !== "/" ? 1 : 0)

    anchors.horizontalCenter: parent.horizontalCenter
    y: s(170)

    text: phone.files.showHidden ? "Pasta vazia" : "Pasta vazia (sem ocultos)"
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(12)
  }
}
