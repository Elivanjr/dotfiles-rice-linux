// views/CalcView.qml — VISÃO 11 — CALCULADORA

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: calcView

  visible: phone.view === "calc"

  // visor
  Rectangle {
    x: s(8)
    y: s(36)
    width: s(264)
    height: s(74)
    radius: s(8)

    color: phone.ov(0.08)

    Text {
      x: s(10)
      y: s(6)
      width: parent.width - s(20)

      horizontalAlignment: Text.AlignRight
      elide: Text.ElideLeft

      text: phone.calc.calcErr
        ? ""
        : phone.calc.calcShow(phone.calc.calcDone ? phone.calc.calcHist : phone.calc.calcLive)

      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    Text {
      x: s(10)
      y: s(22)
      width: parent.width - s(20)
      height: s(46)

      horizontalAlignment: Text.AlignRight
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideLeft
      fontSizeMode: Text.Fit
      minimumPixelSize: s(15)

      text: phone.calc.calcErr
        ? phone.calc.calcErrMsg
        : phone.calc.calcShow(phone.calc.calcExpr === "" ? "0" : phone.calc.calcExpr)

      color: phone.calc.calcErr ? phone.ring : phone.txt
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(32)
    }
  }

  // teclado
  Repeater {
    model: phone.calc.calcKeys

    delegate: Rectangle {
      id: ckey

      required property var modelData
      required property int index

      readonly property bool isSel: index === phone.calc.calcSel

      x: s(8) + (index % 4) * s(67)
      y: s(116) + Math.floor(index / 4) * s(36)
      width: s(63)
      height: s(32)
      radius: s(7)

      color:
        ckey.modelData.kind === "eq" ? phone.pink
          : ckey.modelData.kind === "op" ? Qt.rgba(0.91, 0.63, 0.66, 0.28)
          : ckey.modelData.kind === "fn" ? phone.cCardHi
          : phone.ov(0.10)

      border.width: ckey.isSel ? 2 : 0
      border.color: ckey.modelData.kind === "eq" ? phone.txt : phone.pink

      Text {
        anchors.centerIn: parent

        text: ckey.modelData.t
        color:
          ckey.modelData.kind === "eq" ? (phone.themeDark ? "#1b2733" : "white")
            : ckey.modelData.kind === "op" ? phone.pink
            : phone.txt

        font.family: phone.fontUi
        font.pixelSize: s(16)
        font.bold: ckey.modelData.kind !== "num"
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
          phone.calc.calcSel = ckey.index;
          phone.calc.calcPress(ckey.modelData.k);
        }
      }
    }
  }
}
