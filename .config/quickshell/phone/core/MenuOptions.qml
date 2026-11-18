import QtQuick
import Quickshell
import "../ui"

ViewBase {
  MouseArea {
    visible: phone.menu.optionsOpen

    x: 0
    y: 0
    width: lcd.width
    height: s(303)

    onClicked: phone.menu.optionsOpen = false
  }

  Rectangle {
    visible: phone.menu.optionsOpen

    x: s(8)
    y: s(300) - height
    width: s(142)
    height: optList.height + s(8)
    radius: s(5)

    color: phone.cPop
    border.color: phone.pink
    border.width: 1

    Column {
      id: optList

      x: s(4)
      y: s(4)
      width: parent.width - s(8)

      Repeater {
        model: phone.menu.optLabels

        Rectangle {
          required property string modelData
          required property int index

          width: optList.width
          height: s(22)
          radius: s(3)

          color: index === phone.menu.optSel
            ? Qt.rgba(0.91, 0.63, 0.66, 0.22)
            : "transparent"

          Text {
            x: s(8)
            anchors.verticalCenter: parent.verticalCenter

            text: modelData
            color: index === phone.menu.optSel ? phone.pink : phone.txt
            font.family: phone.fontUi
            font.pixelSize: s(13)
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: phone.menu.optSel = index
            onClicked: phone.menu.optRun(index)
          }
        }
      }
    }
  }
}
