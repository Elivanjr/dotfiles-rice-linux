// views/MusicView.qml — VISÃO 2 — MÚSICA (MPRIS)

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: musicView

  visible: phone.view === "music"

  Text {
    x: s(10)
    y: s(46) - height / 2

    text: "Música"
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  // sem player
  Text {
    visible: !phone.music.hasPlayer
    anchors.centerIn: parent
    width: parent.width - s(40)

    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap

    text: "Nenhum player MPRIS ativo.\nAbra um player de música."
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(14)
  }

  // roda do mouse = volume
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton

    onWheel: function (w) {
      phone.music.changeVolume(w.angleDelta.y > 0 ? 0.05 : -0.05);
    }
  }

  Item {
    anchors.fill: parent
    visible: phone.music.hasPlayer

    // capa
    Rectangle {
      x: s(10)
      y: s(68)
      width: s(104)
      height: s(104)
      radius: s(6)

      color: phone.cCard2
      border.color: phone.cLine
      border.width: 1
      clip: true

      Image {
        anchors.fill: parent
        anchors.margins: 1

        source: phone.music.hasPlayer ? (phone.music.player.trackArtUrl || "") : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
      }
    }

    // título / artista / player
    Column {
      x: s(124)
      y: s(68)
      width: s(148)
      spacing: s(3)

      Text {
        width: parent.width

        text: phone.music.trackTitle
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight

        color: phone.txt
        font.family: phone.fontUi
        font.bold: true
        font.pixelSize: s(15)
      }

      Text {
        width: parent.width

        text: phone.music.trackArtist
        elide: Text.ElideRight

        color: phone.cIcon
        font.family: phone.fontUi
        font.pixelSize: s(13)
      }

      Text {
        width: parent.width

        text: phone.music.hasPlayer ? (phone.music.player.trackAlbum || "") : ""
        visible: text !== ""
        elide: Text.ElideRight

        color: phone.txtMuted
        font.family: phone.fontUi
        font.pixelSize: s(11)
      }

      Text {
        width: parent.width

        text: phone.music.hasPlayer ? phone.music.player.identity : ""
        elide: Text.ElideRight

        color: phone.pink
        font.family: phone.fontUi
        font.pixelSize: s(12)

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: phone.music.cyclePlayer()
        }
      }
    }

    // progresso
    Rectangle {
      id: bar

      x: s(10)
      y: s(186)
      width: s(260)
      height: s(5)
      radius: height / 2

      color: phone.cCardHi

      Rectangle {
        width: parent.width * phone.music.progress
        height: parent.height
        radius: height / 2
        color: phone.pink
      }

      MouseArea {
        anchors.fill: parent
        anchors.topMargin: -s(8)
        anchors.bottomMargin: -s(8)

        cursorShape: Qt.PointingHandCursor

        onClicked: function (mouse) {
          phone.music.seekTo(mouse.x / bar.width);
        }
      }
    }

    Text {
      x: s(10)
      y: s(196)

      text: phone.music.hasPlayer ? phone.music.fmt(phone.music.player.position) : ""
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }

    Text {
      x: s(270) - width
      y: s(196)

      text:
        phone.music.hasPlayer && phone.music.player.lengthSupported
          ? phone.music.fmt(phone.music.player.length)
          : ""

      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }

    // controles
    Repeater {
      model: [
        { k: "prev",   cx: 76,  d: 38 },
        { k: "toggle", cx: 140, d: 46 },
        { k: "next",   cx: 204, d: 38 }
      ]

      Rectangle {
        id: ctl

        required property var modelData
        required property int index

        readonly property bool big: modelData.k === "toggle"

        x: s(modelData.cx) - width / 2
        y: s(240) - height / 2
        width: s(modelData.d)
        height: s(modelData.d)
        radius: width / 2

        color: big ? phone.noteBg : phone.cFoco1
        border.color: big ? "#f08cb2" : phone.cFoco2
        border.width: 1

        opacity: ctlArea.containsMouse ? 1.0 : 0.88

        Glyph {
          anchors.centerIn: parent
          width: s(ctl.big ? 22 : 18)
          height: s(ctl.big ? 22 : 18)

          kind:
            ctl.modelData.k === "toggle"
              ? (phone.music.hasPlayer && phone.music.player.isPlaying
                  ? "pause"
                  : "play")
              : ctl.modelData.k

          stroke: "white"
        }

        MouseArea {
          id: ctlArea

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onClicked: phone.music.press(ctl.index)
        }
      }
    }

    // volume
    Text {
      x: s(10)
      y: s(280) - height / 2

      text: "Volume"
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }

    Rectangle {
      id: volBar

      x: s(60)
      y: s(280) - height / 2
      width: s(160)
      height: s(5)
      radius: height / 2

      color: phone.cCardHi

      Rectangle {
        width: parent.width * phone.music.volumeRatio
        height: parent.height
        radius: height / 2
        color: phone.cIcon
      }

      MouseArea {
        anchors.fill: parent
        anchors.topMargin: -s(8)
        anchors.bottomMargin: -s(8)

        cursorShape: Qt.PointingHandCursor

        onClicked: function (mouse) {
          phone.music.setVolume(mouse.x / volBar.width);
        }
      }
    }

    Text {
      x: s(270) - width
      y: s(280) - height / 2

      text:
        phone.music.hasPlayer && phone.music.player.volumeSupported
          ? Math.round(phone.music.player.volume * 100) + "%"
          : "--"

      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }
  }
}
