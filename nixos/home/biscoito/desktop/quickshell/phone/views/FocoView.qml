// views/FocoView.qml — VISÃO 6 — FOCO

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: focoView

  visible: phone.view === "foco"

  Text {
    x: s(10)
    y: s(46) - height / 2

    text: "Foco"
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  // modos
  Row {
    x: s(8)
    y: s(62)
    spacing: s(6)

    Repeater {
      model: [
        { k: "focus", t: "Foco 25" },
        { k: "short", t: "Pausa 5" },
        { k: "long",  t: "Longa 15" }
      ]

      Rectangle {
        required property var modelData

        readonly property bool on: phone.foco.pomoMode === modelData.k

        width: s(82)
        height: s(22)
        radius: height / 2

        color: on ? phone.cSel : "transparent"
        border.color: on ? phone.pink : phone.cLine
        border.width: 1

        Text {
          anchors.centerIn: parent

          text: modelData.t
          color: parent.on ? phone.pink : phone.txtMuted
          font.family: phone.fontUi
          font.pixelSize: s(12)
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: phone.foco.pomoSetMode(modelData.k)
        }
      }
    }
  }

  // anel de progresso
  Canvas {
    id: pomoRing

    x: s(140) - width / 2
    y: s(164) - height / 2
    width: s(140)
    height: s(140)

    property real ratio: phone.foco.pomoRatio
    property color arcColor:
      phone.foco.pomoMode === "focus" ? phone.pink : phone.cOk

    Connections {
      target: phone

      function onThemeDarkChanged() {
        pomoRing.requestPaint();
      }
    }

    onRatioChanged: requestPaint()
    onArcColorChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
      const ctx = getContext("2d");
      ctx.clearRect(0, 0, width, height);

      const cx = width / 2;
      const cy = height / 2;
      const r = width / 2 - s(8);

      ctx.lineWidth = s(9);
      ctx.lineCap = "round";

      ctx.strokeStyle = phone.cCardHi;
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.stroke();

      if (ratio > 0.002) {
        ctx.strokeStyle = arcColor;
        ctx.beginPath();
        ctx.arc(
          cx, cy, r,
          -Math.PI / 2,
          -Math.PI / 2 + Math.PI * 2 * Math.min(1, ratio),
          false
        );
        ctx.stroke();
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height / 2 - height / 2 - s(6)

      text: phone.foco.fmtMinSec(phone.foco.pomoLeft)
      color: phone.txt
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(34)
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height / 2 + s(16)

      text:
        phone.foco.pomoMode === "focus" ? "FOCO"
        : phone.foco.pomoMode === "short" ? "PAUSA"
        : "PAUSA LONGA"

      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(11)
      font.letterSpacing: s(1.5)
    }

    // clique no anel = iniciar/pausar
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: phone.foco.pomoToggle()
    }
  }

  // ciclos do dia
  Row {
    x: (lcd.width - width) / 2
    y: s(246)
    spacing: s(7)

    Repeater {
      model: 4

      Rectangle {
        required property int index

        readonly property int filled:
          phone.foco.pomoMode === "long" ? 4 : phone.foco.pomoCycles % 4

        width: s(8)
        height: s(8)
        radius: width / 2

        color: index < filled ? phone.pink : phone.cCardHi
      }
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: s(266)

    text: "Ciclos hoje: " + phone.foco.pomoCycles
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(12)
  }
}
