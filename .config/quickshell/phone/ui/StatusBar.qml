// ui/StatusBar.qml
//


import QtQuick
import Quickshell

ViewBase {
  Item {
    id: statusBar

    width: lcd.width
    height: s(34)

    // sinal
    Repeater {
      model: 4

      Rectangle {
        required property int index

        x: s(10 + index * 5.5)
        width: s(3)
        height: s(6 + index * 4)
        y: s(28) - height
        color: index < phone.sys.wifiBars ? phone.cStatus : phone.cDim
      }
    }

    Text {
      id: wifiTxt

      x: s(33)
      y: s(20) - height / 2

      text: phone.sys.wifiLabel
      color: phone.sys.wifiState === "connected" || phone.sys.ethUp ? phone.txt : phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }

    // bluetooth: só aparece ligado; azul quando há aparelho conectado
    Glyph {
      visible: phone.sys.btOn

      x: wifiTxt.x + wifiTxt.width + s(8)
      y: s(20) - height / 2
      width: s(12)
      height: s(12)

      kind: "bluetooth"
      lw: 2.2
      stroke: phone.sys.btConnected ? "#6cb4ff" : "#8aa0b4"
    }

    Text {
      visible: phone.foco.pomoRunning

      x: s(112)
      y: s(20) - height / 2

      text: "\u25CF " + phone.foco.fmtMinSec(phone.foco.pomoLeft)
      color: phone.foco.pomoMode === "focus" ? phone.pink : phone.cOk
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    Text {
      id: clockTxt

      x: (phone.sys.batPct >= 0 ? s(213) : s(240)) - width
      y: s(20) - height / 2

      text: phone.music.clockText()
      color: phone.txt
      font.family: phone.fontUi
      font.pixelSize: s(14)
    }

    // bateria (porcentagem real): ícone e, depois dele, o número
    Rectangle {
      visible: phone.sys.batPct >= 0

      x: s(221)
      y: s(15)
      width: s(25)
      height: s(11)
      radius: s(1.5)

      color: "transparent"
      border.color: phone.cStatus
      border.width: Math.max(1, s(1.2))

      Rectangle {
        x: s(2.5)
        y: s(2.5)
        width: Math.max(
          phone.sys.batPct > 0 ? s(1) : 0,
          (parent.width - s(5)) * phone.sys.batPct / 100
        )
        height: parent.height - s(5)
        radius: s(1)

        color:
          phone.sys.batPct <= 15 && phone.sys.batState !== "Charging"
            ? phone.ring
            : phone.cBatt
      }

      Glyph {
        visible: phone.sys.batState === "Charging"

        anchors.centerIn: parent
        width: s(9)
        height: s(9)

        kind: "bolt"
        stroke: phone.sys.batPct > 45 ? "#16202c" : phone.cStatus
      }
    }

    Text {
      visible: phone.sys.batPct >= 0

      x: s(250)
      y: s(20) - height / 2
      width: s(26)

      text: phone.sys.batPct + "%"
      color:
        phone.sys.batPct <= 15 && phone.sys.batState !== "Charging"
          ? phone.ring
          : phone.txtMuted

      font.family: phone.fontUi
      font.pixelSize: s(10)
    }
  }
}
