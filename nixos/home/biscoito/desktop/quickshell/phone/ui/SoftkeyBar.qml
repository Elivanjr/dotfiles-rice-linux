// ui/SoftkeyBar.qml
//
// SOFTKEYS (comuns às visões)

import QtQuick
import Quickshell

ViewBase {
  Rectangle {
    x: s(6)
    y: s(303)
    width: lcd.width - s(12)
    height: 1
    color: phone.hair
  }

  Text {
    x: s(10)
    y: s(314.5) - height / 2

    text: phone.controls.softLeftText
    color: phone.txt
    font.family: phone.fontUi
    font.pixelSize: s(14)

    MouseArea {
      anchors.fill: parent
      anchors.margins: -s(6)
      cursorShape: Qt.PointingHandCursor
      onClicked: phone.controls.softLeft()
    }
  }

  Text {
    x: (lcd.width - width) / 2
    y: s(314.5) - height / 2

    text: phone.controls.softCenterText
    color: phone.txt
    font.family: phone.fontUi
    font.pixelSize: s(14)

    MouseArea {
      anchors.fill: parent
      anchors.margins: -s(6)
      cursorShape: Qt.PointingHandCursor
      onClicked: phone.controls.softCenter()
    }
  }

  Text {
    x: s(270) - width
    y: s(314.5) - height / 2

    text: phone.controls.softRightText
    color: phone.txt
    font.family: phone.fontUi
    font.pixelSize: s(14)

    MouseArea {
      anchors.fill: parent
      anchors.margins: -s(6)
      cursorShape: Qt.PointingHandCursor
      onClicked: phone.controls.softRight()
    }
  }
}
