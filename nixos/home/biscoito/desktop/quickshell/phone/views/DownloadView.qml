// views/DownloadView.qml — VISÃO 14 — BAIXAR (yt-dlp)

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: dlView

  visible: phone.view === "dl"

  Text {
    x: s(10)
    y: s(46) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.dl.dlTitleBar
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  Text {
    x: s(10)
    y: s(66) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.dl.dlSubtitle
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(11)
  }

  // ---------------- 1) link ----------------

  Item {
    visible: phone.dl.dlStage === "url"
    anchors.fill: parent

    Rectangle {
      x: s(8)
      y: s(78)
      width: s(264)
      height: s(32)
      radius: s(5)

      color: phone.cSel
      border.width: 1
      border.color: phone.pink

      Text {
        x: s(10)
        width: s(40)
        anchors.verticalCenter: parent.verticalCenter

        text: "Link"
        color: phone.txtMuted
        font.family: phone.fontUi
        font.pixelSize: s(11)
      }

      Text {
        x: s(46)
        width: parent.width - s(54)
        anchors.verticalCenter: parent.verticalCenter

        elide: Text.ElideLeft
        textFormat: Text.PlainText

        text: phone.dl.dlUrl + "_"
        color: phone.txt
        font.family: phone.fontMono
        font.pixelSize: s(11)
      }

      Text {
        visible: phone.dl.dlUrl === ""

        x: s(46)
        width: parent.width - s(54)
        anchors.verticalCenter: parent.verticalCenter

        elide: Text.ElideRight

        text: "https://…"
        color: phone.ov(0.28)
        font.family: phone.fontMono
        font.pixelSize: s(11)
      }
    }

    Text {
      visible: phone.dl.dlMsg === ""

      x: s(10)
      y: s(120)
      width: s(260)

      wrapMode: Text.WordWrap

      text: "Cole o link do vídeo (Colar ou Ctrl+V) e toque em Buscar. Vídeo vai para Vídeos; só áudio, para Música."
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(10.5)
    }

    Text {
      visible: phone.dl.dlMsg !== ""

      x: s(10)
      y: s(120)
      width: s(260)

      wrapMode: Text.WordWrap
      maximumLineCount: 8
      elide: Text.ElideRight

      text: phone.dl.dlMsg
      color: phone.ring
      font.family: phone.fontUi
      font.pixelSize: s(10.5)
    }
  }

  // ---------------- 2) buscando ----------------

  Item {
    visible: phone.dl.dlStage === "loading"
    anchors.fill: parent

    Text {
      x: s(16)
      y: s(150)
      width: s(248)

      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WrapAnywhere
      maximumLineCount: 3
      elide: Text.ElideRight

      text: phone.dl.dlUrl
      color: phone.txtMuted
      font.family: phone.fontMono
      font.pixelSize: s(10)
    }

    Rectangle {
      x: s(10)
      y: s(120)
      width: s(260)
      height: s(4)
      radius: height / 2
      color: phone.ov(0.1)

      Rectangle {
        id: dlSweep

        width: s(70)
        height: parent.height
        radius: height / 2
        color: phone.pink

        SequentialAnimation on x {
          running: phone.dl.dlStage === "loading"
          loops: Animation.Infinite

          NumberAnimation { from: 0; to: s(190); duration: 900; easing.type: Easing.InOutQuad }
          NumberAnimation { from: s(190); to: 0; duration: 900; easing.type: Easing.InOutQuad }
        }
      }
    }
  }

  // ---------------- 3) escolher qualidade ----------------

  Item {
    visible: phone.dl.dlStage === "pick"
    anchors.fill: parent

    Text {
      x: s(10)
      y: s(78)
      width: s(260)

      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight

      text: phone.dl.dlTitle
      color: phone.txt
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(12)
    }

    ListView {
      id: dlList

      x: s(8)
      y: s(116)
      width: s(264)
      height: s(158)

      clip: true
      boundsBehavior: Flickable.StopAtBounds

      model: phone.dl.dlOptions

      Connections {
        target: phone.dl

        function onDlSelChanged() {
          dlList.positionViewAtIndex(phone.dl.dlSel, ListView.Contain);
        }
      }

      delegate: Item {
        id: orow

        required property var modelData
        required property int index

        readonly property bool isSel: index === phone.dl.dlSel

        width: dlList.width
        height: s(30)

        Rectangle {
          visible: orow.isSel
          anchors.fill: parent
          anchors.bottomMargin: s(2)
          radius: s(4)
          color: phone.cSel
        }

        Text {
          x: s(10)
          width: parent.width - s(20)
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -s(1)

          elide: Text.ElideRight
          textFormat: Text.PlainText

          text: orow.modelData.rotulo
          color: orow.isSel ? phone.pink : phone.txt
          font.family: phone.fontUi
          font.bold: orow.isSel
          font.pixelSize: s(12)
        }

        MouseArea {
          anchors.fill: parent

          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onEntered: phone.dl.dlSel = orow.index
          onClicked: {
            phone.dl.dlSel = orow.index;
            phone.dl.dlStart();
          }
        }
      }
    }

    Text {
      x: s(10)
      y: s(286) - height / 2
      width: s(260)

      elide: Text.ElideRight

      text: phone.dl.dlMsg !== "" ? phone.dl.dlMsg : "↑↓ escolhe · Enter baixa"
      color: phone.dl.dlMsg !== "" ? phone.ring : phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(10.5)
    }
  }

  // ---------------- 4) baixando ----------------

  Item {
    visible: phone.dl.dlStage === "down"
    anchors.fill: parent

    Text {
      x: s(10)
      y: s(82)
      width: s(260)

      wrapMode: Text.WordWrap
      maximumLineCount: 3
      elide: Text.ElideRight

      text: phone.dl.dlTitle
      color: phone.txt
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(12)
    }

    Rectangle {
      x: s(10)
      y: s(158)
      width: s(260)
      height: s(10)
      radius: height / 2
      color: phone.ov(0.1)

      Rectangle {
        width: parent.width * Math.max(0, Math.min(100, phone.dl.dlPct)) / 100
        height: parent.height
        radius: height / 2
        color: phone.pink

        Behavior on width {
          NumberAnimation { duration: 250 }
        }
      }
    }

    Text {
      x: s(10)
      y: s(176)
      width: s(260)

      elide: Text.ElideRight

      text: phone.dl.dlDetail
      color: phone.txt
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    Text {
      x: s(10)
      y: s(196)
      width: s(260)

      elide: Text.ElideRight

      text: phone.dl.dlStatus
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }
  }

  // ---------------- 5) pronto ----------------

  Item {
    visible: phone.dl.dlStage === "done"
    anchors.fill: parent

    Text {
      x: s(10)
      y: s(84)
      width: s(260)

      wrapMode: Text.WordWrap
      maximumLineCount: 3
      elide: Text.ElideRight

      text: phone.dl.dlTitle
      color: phone.txt
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(12)
    }

    Rectangle {
      x: s(8)
      y: s(140)
      width: s(264)
      height: s(70)
      radius: s(6)
      color: phone.cPop

      Text {
        x: s(10)
        y: s(8)
        width: parent.width - s(20)
        height: parent.height - s(16)

        wrapMode: Text.WrapAnywhere
        maximumLineCount: 4
        elide: Text.ElideMiddle
        textFormat: Text.PlainText

        text: phone.dl.dlFile
        color: phone.cCode
        font.family: phone.fontMono
        font.pixelSize: s(10)
      }
    }

    Text {
      x: s(10)
      y: s(220)
      width: s(260)

      elide: Text.ElideRight

      text: "Pasta: Enter ou botão do meio"
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(10.5)
    }
  }
}
