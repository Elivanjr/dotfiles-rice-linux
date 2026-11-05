// views/ScheduleView.qml — VISÃO 13 — AGENDAR (comandos com o `at`)

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: schedView

  visible: phone.view === "sched"

  Text {
    x: s(10)
    y: s(46) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.sched.schedTitle
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  Text {
    x: s(10)
    y: s(66) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.sched.schedSubtitle
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(11)
  }

  // ---------------- lista de jobs ----------------

  Item {
    visible: phone.sched.schedStage === "list"
    anchors.fill: parent

    ListView {
      id: schedList

      x: s(8)
      y: s(78)
      width: s(264)
      height: s(196)

      clip: true
      boundsBehavior: Flickable.StopAtBounds

      model: phone.sched.schedModel

      Connections {
        target: phone.sched

        function onSchedSelChanged() {
          schedList.positionViewAtIndex(phone.sched.schedSel, ListView.Contain);
        }
      }

      delegate: Item {
        id: jrow

        required property string jobId
        required property real epoch
        required property bool running
        required property string cmd
        required property int index

        readonly property bool isSel: index === phone.sched.schedSel

        width: schedList.width
        height: s(40)

        Rectangle {
          visible: jrow.isSel
          anchors.fill: parent
          anchors.bottomMargin: s(2)
          radius: s(4)
          color: phone.cSel
          border.width: phone.sched.schedConfirm ? 1 : 0
          border.color: phone.ring
        }

        Glyph {
          x: s(8)
          y: s(6)
          width: s(14)
          height: s(14)

          kind: "timer"
          stroke: jrow.running ? phone.cOk : (jrow.isSel ? phone.pink : phone.cIcon)
        }

        Text {
          x: s(28)
          y: s(5)
          width: parent.width - s(36)

          elide: Text.ElideRight

          text: jrow.running ? "executando…" : phone.sched.whenText(jrow.epoch)
          color: jrow.isSel ? phone.pink : phone.txt
          font.family: phone.fontUi
          font.bold: jrow.isSel
          font.pixelSize: s(12)
        }

        Text {
          x: s(28)
          y: s(21)
          width: parent.width - s(36)

          elide: Text.ElideRight
          textFormat: Text.PlainText

          text: "#" + jrow.jobId + "  " + jrow.cmd
          color: phone.cCode
          font.family: phone.fontMono
          font.pixelSize: s(10)
        }

        MouseArea {
          anchors.fill: parent

          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onEntered: phone.sched.schedSel = jrow.index
          onClicked: phone.sched.schedSel = jrow.index
        }
      }
    }

    // vazio / erro ficam fora do ListView (senão rolariam junto)
    Text {
      visible: phone.sched.schedModel.count === 0 && phone.sched.schedListError === ""

      x: s(16)
      y: s(150)
      width: s(248)
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap

      text: "Nada na fila do at.\nToque em Novo para agendar um comando."
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    Text {
      visible: phone.sched.schedListError !== ""

      x: s(16)
      y: s(130)
      width: s(248)
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      maximumLineCount: 5
      elide: Text.ElideRight

      text: phone.sched.schedListError + "\nConfira se o atd está ativo."
      color: phone.ring
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    Text {
      x: s(10)
      y: s(286) - height / 2
      width: s(260)

      elide: Text.ElideRight

      text: phone.sched.schedStatus !== ""
        ? phone.sched.schedStatus
        : "Enter remove · N novo · R atualiza"

      color: phone.sched.schedConfirm || phone.sched.schedStatus.indexOf("Falha") === 0
        ? phone.ring
        : phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }
  }

  // ---------------- 1/3 comando ----------------

  Item {
    visible: phone.sched.schedStage === "cmd"
    anchors.fill: parent

    Rectangle {
      x: s(8)
      y: s(78)
      width: s(264)
      height: s(74)
      radius: s(5)

      color: phone.cSel
      border.width: 1
      border.color: phone.pink

      Text {
        x: s(10)
        y: s(6)

        text: "Comando"
        color: phone.txtMuted
        font.family: phone.fontUi
        font.pixelSize: s(10.5)
      }

      Text {
        x: s(10)
        y: s(22)
        width: parent.width - s(20)
        height: parent.height - s(28)

        wrapMode: Text.WrapAnywhere
        maximumLineCount: 3
        elide: Text.ElideRight
        textFormat: Text.PlainText

        text: phone.sched.schedCmd.slice(-110) + "_"
        color: phone.txt
        font.family: phone.fontMono
        font.pixelSize: s(11)
      }

      Text {
        visible: phone.sched.schedCmd === ""

        x: s(10)
        y: s(22)
        width: parent.width - s(20)

        elide: Text.ElideRight

        text: "notify-send \"Oi\"   ·   mpv ~/Vídeos/x.mkv"
        color: phone.ov(0.28)
        font.family: phone.fontMono
        font.pixelSize: s(11)
      }
    }

    Text {
      x: s(10)
      y: s(164)
      width: s(260)

      wrapMode: Text.WordWrap

      text: "Escreva o comando como no terminal. Ctrl+V cola. Depois você escolhe o dia e a hora."
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(10.5)
    }

    Text {
      visible: phone.sched.schedMsg !== ""

      x: s(10)
      y: s(222)
      width: s(260)

      wrapMode: Text.WordWrap
      maximumLineCount: 3
      elide: Text.ElideRight

      text: phone.sched.schedMsg
      color: phone.ring
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }
  }

  // ---------------- 2/3 calendário ----------------

  Item {
    visible: phone.sched.schedStage === "date"
    anchors.fill: parent

    // mês: ‹ novembro de 2026 ›
    Item {
      x: s(8)
      y: s(76)
      width: s(264)
      height: s(20)

      Text {
        x: 0
        width: s(28)
        height: parent.height

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: "‹"
        color: phone.pink
        font.family: phone.fontUi
        font.pixelSize: s(18)

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor

          onClicked: phone.sched.schedAddMonths(-1)
        }
      }

      Text {
        x: s(28)
        width: parent.width - s(56)
        height: parent.height

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: phone.sched.schedMonthLabel
        color: phone.txt
        font.family: phone.fontUi
        font.bold: true
        font.pixelSize: s(12.5)
      }

      Text {
        x: parent.width - s(28)
        width: s(28)
        height: parent.height

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: "›"
        color: phone.pink
        font.family: phone.fontUi
        font.pixelSize: s(18)

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor

          onClicked: phone.sched.schedAddMonths(1)
        }
      }
    }

    // dias da semana
    Repeater {
      model: ["D", "S", "T", "Q", "Q", "S", "S"]

      Text {
        required property string modelData
        required property int index

        x: s(8) + index * (s(264) / 7)
        y: s(100)
        width: s(264) / 7
        horizontalAlignment: Text.AlignHCenter

        text: modelData
        color: index === 0 ? phone.ring : phone.txtMuted
        font.family: phone.fontUi
        font.pixelSize: s(10.5)
      }
    }

    // grade 7 x 6
    Repeater {
      model: 42

      Item {
        id: cell

        required property int index

        readonly property var c: phone.sched.schedCell(index)

        x: s(8) + (index % 7) * (s(264) / 7)
        y: s(114) + Math.floor(index / 7) * s(23)
        width: s(264) / 7
        height: s(23)

        Rectangle {
          anchors.centerIn: parent
          width: s(22)
          height: s(20)
          radius: s(5)

          color: cell.c.sel ? phone.pink : "transparent"
          border.width: (cell.c.today && !cell.c.sel) ? 1 : 0
          border.color: phone.pink
        }

        Text {
          anchors.centerIn: parent

          text: cell.c.day
          color: cell.c.sel ? "#1a1a1a"
            : cell.c.past ? phone.ov(0.2)
            : cell.c.inMonth ? phone.txt
            : phone.ov(0.35)
          font.family: phone.fontUi
          font.bold: cell.c.sel || cell.c.today
          font.pixelSize: s(11.5)
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: cell.c.past ? Qt.ArrowCursor : Qt.PointingHandCursor

          onClicked: phone.sched.schedClickCell(cell.index)
        }
      }
    }

    Text {
      x: s(10)
      y: s(260)
      width: s(260)

      elide: Text.ElideRight

      text: phone.sched.schedDateLabel
      color: phone.pink
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(12)
    }

    Text {
      x: s(10)
      y: s(280)
      width: s(260)

      elide: Text.ElideRight

      text: "←→ dia · ↑↓ semana · PgUp/PgDn mês · T hoje"
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(10)
    }
  }

  // ---------------- 3/3 hora ----------------

  Item {
    visible: phone.sched.schedStage === "time"
    anchors.fill: parent

    Text {
      x: s(10)
      y: s(80)
      width: s(260)

      elide: Text.ElideRight

      text: phone.sched.schedDateLabel
      color: phone.pink
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(13)
    }

    Repeater {
      model: 2

      Rectangle {
        required property int index

        readonly property bool on: phone.sched.schedTimeField === index

        x: index === 0 ? s(36) : s(156)
        y: s(104)
        width: s(88)
        height: s(66)
        radius: s(8)

        color: on ? phone.cSel : phone.ov(0.07)
        border.width: on ? 2 : 0
        border.color: phone.pink

        Text {
          anchors.centerIn: parent

          text: index === 0 ? phone.sched.schedHourText : phone.sched.schedMinuteText
          color: parent.on ? phone.pink : phone.txt
          font.family: phone.fontUi
          font.bold: true
          font.pixelSize: s(38)
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          y: parent.height - s(14)

          text: index === 0 ? "hora" : "min"
          color: phone.txtMuted
          font.family: phone.fontUi
          font.pixelSize: s(9.5)
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor

          onClicked: phone.sched.schedSetField(index)

          onWheel: (w) => {
            phone.sched.schedSetField(index);
            phone.sched.schedAdjustTime(w.angleDelta.y > 0 ? 1 : -1);
          }
        }
      }
    }

    Text {
      x: s(124)
      y: s(104)
      width: s(32)
      height: s(66)

      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter

      text: ":"
      color: phone.txt
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(38)
    }

    // atalhos relativos a agora
    Row {
      x: s(8)
      y: s(182)
      spacing: s(5)

      Repeater {
        model: phone.sched.schedPresets

        Rectangle {
          required property var modelData
          required property int index

          readonly property bool on: phone.sched.schedPresetIdx === index

          width: s(14) + modelData.t.length * s(6)
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
            font.pixelSize: s(10.5)
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onClicked: phone.sched.schedApplyPreset(index)
          }
        }
      }
    }

    Text {
      x: s(10)
      y: s(212)
      width: s(260)

      wrapMode: Text.WrapAnywhere
      maximumLineCount: 2
      elide: Text.ElideRight
      textFormat: Text.PlainText

      text: "$ " + phone.sched.schedCmd
      color: phone.cCode
      font.family: phone.fontMono
      font.pixelSize: s(10)
    }

    Text {
      visible: phone.sched.schedMsg !== ""

      x: s(10)
      y: s(246)
      width: s(260)

      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight

      text: phone.sched.schedMsg
      color: phone.ring
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }

    Text {
      x: s(10)
      y: s(286) - height / 2
      width: s(260)

      elide: Text.ElideRight

      text: phone.sched.schedBusy ? "Agendando…" : "↑↓ ajusta · ←→ hora/min · digite · Tab rápido"
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(10)
    }
  }
}
