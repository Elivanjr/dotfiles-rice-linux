// views/WallView.qml — VISÃO 4 — GALERIA DE WALLPAPERS

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: wallView

  visible: phone.view === "wall"

  // nome do wallpaper selecionado (como o menu faz com os apps)
  Text {
    x: s(10)
    y: s(46) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text:
      phone.walls.wallpapers.length > 0
        ? phone.walls.baseName(phone.walls.wallpapers[phone.walls.wallSelected])
        : "Wallpaper"

    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  GridView {
    id: wallGrid

    // avisa a lógica qual é este item (usado para rolar)
    Binding { target: phone.walls; property: "wallGridRef"; value: wallGrid }

    x: s(8)
    y: s(62)
    width: s(264)
    height: s(234)

    clip: true
    cellWidth: s(88)
    cellHeight: s(62)
    boundsBehavior: Flickable.StopAtBounds

    model: phone.walls.wallpapers

    delegate: Item {
      id: wcell

      required property string modelData
      required property int index

      readonly property bool isSel: index === phone.walls.wallSelected
      readonly property bool isApplied: modelData === phone.walls.appliedWall

      width: wallGrid.cellWidth
      height: wallGrid.cellHeight

      Rectangle {
        anchors.fill: parent
        anchors.margins: s(3)

        color: phone.cCard2
        border.color: phone.cLine
        border.width: 1
        clip: true

        Image {
          anchors.fill: parent
          anchors.margins: 1

          source: phone.walls.fileUrl(wcell.modelData)

          // decodifica já reduzido (wallpapers são grandes)
          sourceSize.width: 200

          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: true
        }
      }

      // anel de seleção
      Rectangle {
        visible: wcell.isSel

        anchors.fill: parent
        anchors.margins: s(1.5)
        radius: s(3)

        color: "transparent"
        border.color: phone.ring
        border.width: Math.max(1.5, s(2))
      }

      // marca do wallpaper aplicado
      Rectangle {
        visible: wcell.isApplied

        x: parent.width - width - s(8)
        y: s(8)
        width: s(9)
        height: s(9)
        radius: width / 2

        color: phone.pink
        border.color: "white"
        border.width: 1
      }

      MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: phone.walls.wallSelected = wcell.index
        onClicked: phone.walls.applyWall(wcell.modelData)
      }
    }
  }

  Text {
    visible: phone.walls.wallpapers.length === 0
    anchors.horizontalCenter: parent.horizontalCenter
    y: s(130)
    width: parent.width - s(30)

    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap

    text: "Nenhuma imagem em\n" + phone.walls.wallDir
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(12)
  }
}
