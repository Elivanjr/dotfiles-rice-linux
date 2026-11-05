// ui/OptionPopups.qml
//
// clique fora fecha; cobre só acima da linha das softkeys

import QtQuick
import Quickshell

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

  // ---------------- menu de opções do SSH ----------------

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

  // ---------------- menu de opções da IA ----------------

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

  // ---------------- menu de opções das Configurações ----------------

  MouseArea {
    visible: phone.config.setOptOpen

    x: 0
    y: 0
    width: lcd.width
    height: s(303)

    onClicked: phone.config.setOptOpen = false
  }

  Rectangle {
    visible: phone.config.setOptOpen

    x: s(8)
    y: s(300) - height
    width: s(176)
    height: setOptList.height + s(8)
    radius: s(5)

    color: phone.cPop
    border.color: phone.pink
    border.width: 1

    Column {
      id: setOptList

      x: s(4)
      y: s(4)
      width: parent.width - s(8)

      Repeater {
        model: phone.config.setPageOpts

        Rectangle {
          required property var modelData
          required property int index

          width: setOptList.width
          height: s(24)
          radius: s(3)

          color: index === phone.config.setOptSel
            ? Qt.rgba(0.91, 0.63, 0.66, 0.22)
            : "transparent"

          Text {
            x: s(8)
            width: parent.width - s(12)
            anchors.verticalCenter: parent.verticalCenter

            elide: Text.ElideRight

            text: modelData.t
            color: index === phone.config.setOptSel ? phone.pink : phone.txt
            font.family: phone.fontUi
            font.pixelSize: s(13)
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: phone.config.setOptSel = index
            onClicked: phone.config.setOptRun(modelData.k)
          }
        }
      }
    }
  }
}
