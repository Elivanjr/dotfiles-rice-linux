import QtQuick
import Quickshell
import "../../ui"

ViewBase {
  MouseArea {
    visible: phone.ssh.sshOptOpen

    x: 0
    y: 0
    width: lcd.width
    height: s(303)

    onClicked: phone.ssh.sshOptOpen = false
  }

  Rectangle {
    visible: phone.ssh.sshOptOpen

    x: s(8)
    y: s(300) - height
    width: s(176)
    height: sshOptList.height + s(8)
    radius: s(5)

    color: phone.cPop
    border.color: phone.pink
    border.width: 1

    Column {
      id: sshOptList

      x: s(4)
      y: s(4)
      width: parent.width - s(8)

      Repeater {
        model: phone.ssh.sshOpts

        Rectangle {
          required property var modelData
          required property int index

          width: sshOptList.width
          height: s(24)
          radius: s(3)

          color: index === phone.ssh.sshOptSel
            ? Qt.rgba(0.91, 0.63, 0.66, 0.22)
            : "transparent"

          Text {
            x: s(8)
            width: parent.width - s(12)
            anchors.verticalCenter: parent.verticalCenter

            elide: Text.ElideRight

            text: modelData.t
            color: index === phone.ssh.sshOptSel ? phone.pink : phone.txt
            font.family: phone.fontUi
            font.pixelSize: s(13)
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: phone.ssh.sshOptSel = index
            onClicked: phone.ssh.sshOptRun(modelData.k)
          }
        }
      }
    }
  }
}
