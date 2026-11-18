// ui/BodyButtons.qml
//
// BOTÕES LATERAIS: anterior | play/pause | próxima

import QtQuick
import Quickshell

ViewBase {
  id: root

  Repeater {
    model: [
      { y0: 143, y1: 199, i: 0 },
      { y0: 199, y1: 276, i: 1 },
      { y0: 276, y1: 334, i: 2 }
    ]

    Item {
      required property var modelData

      x: fx(32)
      y: fy(modelData.y0)
      width: s(20)
      height: s(modelData.y1 - modelData.y0)

      Rectangle {
        anchors.fill: parent
        radius: s(6)
        color: "white"
        opacity: sideArea.pressed ? 0.25 : (sideArea.containsMouse ? 0.10 : 0)
      }

      MouseArea {
        id: sideArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: phone.music.press(modelData.i)
      }
    }
  }

  // ------------------------------------------------------------
  // BOTÕES DE METAL: ✉ Música | ⓘ Menu | 📖 página | 📷 fechar
  // ------------------------------------------------------------

  Repeater {
    model: [
      { cx: 85,  i: 0 },
      { cx: 170, i: 1 },
      { cx: 255, i: 2 },
      { cx: 340, i: 3 }
    ]

    Item {
      required property var modelData

      x: fx(modelData.cx - 39)
      y: fy(481)
      width: s(78)
      height: s(51)

      Rectangle {
        anchors.fill: parent
        radius: s(5)
        color: "white"
        opacity: metalArea.pressed ? 0.30 : (metalArea.containsMouse ? 0.12 : 0)
      }

      MouseArea {
        id: metalArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: phone.controls.metal(modelData.i)
      }
    }
  }

  // ------------------------------------------------------------
  // TECLADO: softkeys (traços) | ligar / desligar | D-pad + OK
  // (coordenadas em px do PNG)
  // ------------------------------------------------------------

  Repeater {
    model: [
      { k: "sl",    x0: 61,  y0: 564, x1: 149, y1: 600, round: false },
      { k: "sr",    x0: 275, y0: 564, x1: 363, y1: 600, round: false },
      { k: "call",  x0: 61,  y0: 607, x1: 149, y1: 643, round: false },
      { k: "end",   x0: 275, y0: 607, x1: 363, y1: 643, round: false },

      { k: "up",    x0: 186, y0: 566, x1: 238, y1: 584, round: false },
      { k: "down",  x0: 186, y0: 628, x1: 238, y1: 648, round: false },
      { k: "left",  x0: 166, y0: 584, x1: 190, y1: 628, round: false },
      { k: "right", x0: 234, y0: 584, x1: 258, y1: 628, round: false },
      { k: "ok",    x0: 190, y0: 584, x1: 234, y1: 628, round: true }
    ]

    Item {
      required property var modelData

      x: fx(modelData.x0)
      y: fy(modelData.y0)
      width: s(modelData.x1 - modelData.x0)
      height: s(modelData.y1 - modelData.y0)

      Rectangle {
        anchors.fill: parent
        radius: modelData.round ? width / 2 : s(6)
        color: "white"
        opacity: padArea.pressed ? 0.30 : (padArea.containsMouse ? 0.12 : 0)
      }

      MouseArea {
        id: padArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: phone.controls.pad(modelData.k)
      }
    }
  }
}
