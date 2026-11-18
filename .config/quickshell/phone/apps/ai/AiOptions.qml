import QtQuick
import Quickshell
import "../../ui"

ViewBase {
  MouseArea {
    visible: phone.ai.aiOptOpen

    x: 0
    y: 0
    width: lcd.width
    height: s(303)

    onClicked: phone.ai.aiOptOpen = false
  }

  Rectangle {
    visible: phone.ai.aiOptOpen

    x: s(8)
    y: s(300) - height
    width: s(200)
    height: aiOptView.height + s(8)
    radius: s(5)

    color: phone.cPop
    border.color: phone.pink
    border.width: 1

    ListView {
      id: aiOptView

      // avisa a lógica qual é este item (usado para rolar)
      Binding { target: phone.ai; property: "aiOptViewRef"; value: aiOptView }

      x: s(4)
      y: s(4)
      width: parent.width - s(8)
      height: Math.min(count, 8) * s(24)

      clip: true
      interactive: false

      model: phone.ai.aiOpts

      delegate: Rectangle {
        required property var modelData
        required property int index

        width: aiOptView.width
        height: s(24)
        radius: s(3)

        color: index === phone.ai.aiOptSel
          ? Qt.rgba(0.91, 0.63, 0.66, 0.22)
          : "transparent"

        Text {
          x: s(8)
          width: parent.width - s(12)
          anchors.verticalCenter: parent.verticalCenter

          elide: Text.ElideRight

          text: modelData.t
          color: index === phone.ai.aiOptSel ? phone.pink : phone.txt
          font.family: phone.fontUi
          font.pixelSize: s(13)
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onEntered: phone.ai.aiOptSel = index
          onClicked: phone.ai.aiOptRun(modelData.k)
        }
      }
    }
  }
}
