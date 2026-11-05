// views/TermView.qml — VISÃO 12 — TERMINAL (bash local)

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: termView

  visible: phone.view === "term"

  Text {
    x: s(10)
    y: s(46) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: "Terminal"
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  Text {
    x: s(10)
    y: s(66) - height / 2
    width: s(260)

    elide: Text.ElideLeft

    text: phone.term.termCwdShort
    color: phone.txtMuted
    font.family: phone.fontMono
    font.pixelSize: s(11)
  }

  ListView {
    id: termList

    // avisa a lógica qual é este item (usado para rolar)
    Binding { target: phone.term; property: "termListRef"; value: termList }

    x: s(8)
    y: s(76)
    width: s(264)
    height: s(194)

    clip: true
    boundsBehavior: Flickable.StopAtBounds

    model: phone.term.termModel

    onCountChanged: {
      if (phone.term.termStick)
        Qt.callLater(function () { termList.positionViewAtEnd(); });
    }

    onMovementEnded: phone.term.termStick = termList.atYEnd

    delegate: Text {
      required property string kind
      required property string txt

      width: termList.width

      text: txt === "" ? " " : txt
      textFormat: Text.PlainText
      wrapMode: Text.WrapAnywhere

      font.family: phone.fontMono
      font.pixelSize: s(10.5)

      color:
        kind === "cmd" ? phone.pink
          : kind === "err" ? phone.ring
          : kind === "sys" ? phone.txtMuted
          : phone.cCode
    }
  }

  // linha de comando
  Rectangle {
    x: s(8)
    y: s(276)
    width: s(264)
    height: s(22)
    radius: s(5)
    color: phone.ov(0.09)

    Text {
      x: s(8)
      anchors.verticalCenter: parent.verticalCenter

      text: phone.term.termBusy > 0 ? "…" : "$"
      color: phone.pink
      font.family: phone.fontMono
      font.pixelSize: s(12)
    }

    Text {
      x: s(22)
      width: parent.width - s(30)
      anchors.verticalCenter: parent.verticalCenter

      elide: Text.ElideLeft

      text: phone.term.termInput + "_"
      color: phone.txt
      font.family: phone.fontMono
      font.pixelSize: s(12)
    }
  }
}
