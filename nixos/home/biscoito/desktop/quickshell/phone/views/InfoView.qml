// views/InfoView.qml — VISÃO 3 — INFO DO SISTEMA

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: infoView

  visible: phone.view === "info"

  Text {
    x: s(10)
    y: s(46) - height / 2

    text: "Sistema"
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  // foto de perfil
  Rectangle {
    x: s(10)
    y: s(68)
    width: s(52)
    height: s(52)

    color: phone.cCard2
    border.color: phone.cLine
    border.width: 1
    clip: true

    Text {
      anchors.centerIn: parent

      text: (phone.info.sysInfo.user || "?").charAt(0).toUpperCase()
      color: phone.txtMuted
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(22)
    }

    Image {
      anchors.fill: parent
      anchors.margins: 1

      source: phone.photoSource + "?r=" + phone.files.photoRev
      cache: false
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      smooth: true
    }
  }

  // usuário @ host
  Text {
    x: s(74)
    y: s(84) - height / 2
    width: s(190)

    elide: Text.ElideRight

    text: phone.info.sysInfo.user || Quickshell.env("USER")
    color: phone.txt
    font.family: phone.fontUi
    font.bold: true
    font.pixelSize: s(17)
  }

  Text {
    x: s(74)
    y: s(106) - height / 2
    width: s(190)

    elide: Text.ElideRight

    text: phone.info.sysInfo.host ? "@ " + phone.info.sysInfo.host : ""
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(13)
  }

  // linhas
  Repeater {
    model: phone.info.infoRows

    Item {
      required property var modelData
      required property int index

      x: s(10)
      y: s(132 + index * 20)
      width: s(260)
      height: s(20)

      Text {
        anchors.verticalCenter: parent.verticalCenter

        text: modelData.l
        color: phone.txtMuted
        font.family: phone.fontUi
        font.pixelSize: s(11)
      }

      Text {
        x: s(62)
        width: parent.width - s(62)
        anchors.verticalCenter: parent.verticalCenter

        elide: Text.ElideRight

        text: modelData.v
        color: phone.txt
        font.family: phone.fontUi
        font.pixelSize: s(12)
      }
    }
  }

  // memória (texto + barra)
  Text {
    x: s(10)
    y: s(262) - height / 2

    text: "Memória"
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(11)
  }

  Text {
    x: s(72)
    y: s(262) - height / 2

    text:
      phone.info.memTotalGiB > 0
        ? phone.info.memUsedGiB.toFixed(2) + " / "
          + phone.info.memTotalGiB.toFixed(2) + " GiB ("
          + Math.round(phone.info.memRatio * 100) + "%)"
        : "--"

    color: phone.txt
    font.family: phone.fontUi
    font.pixelSize: s(12)
  }

  Rectangle {
    x: s(10)
    y: s(276)
    width: s(260)
    height: s(5)
    radius: height / 2

    color: phone.cCardHi

    Rectangle {
      width: parent.width * phone.info.memRatio
      height: parent.height
      radius: height / 2
      color: phone.info.memRatio > 0.85 ? phone.ring : phone.pink
    }
  }

  Text {
    visible: phone.files.avatarStatus !== ""

    x: s(10)
    y: s(292) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.files.avatarStatus
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(11)
  }
}
