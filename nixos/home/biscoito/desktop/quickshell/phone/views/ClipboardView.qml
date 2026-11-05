// views/ClipboardView.qml — VISÃO 15 — CLIPBOARD (cliphist)

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: clipView

  visible: phone.view === "clip"

  Text {
    x: s(10)
    y: s(46) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.clip.clipTitle
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  Text {
    x: s(10)
    y: s(66) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.clip.clipSubtitle
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(11)
  }

  // ---------------- lista ----------------

  Item {
    visible: phone.clip.clipStage === "list"
    anchors.fill: parent

    // busca (o teclado digita direto aqui)
    Rectangle {
      x: s(8)
      y: s(78)
      width: s(264)
      height: s(26)
      radius: s(5)

      color: phone.clip.clipFilter !== "" ? phone.cSel : phone.ov(0.07)
      border.width: phone.clip.clipFilter !== "" ? 1 : 0
      border.color: phone.pink

      Text {
        x: s(10)
        width: parent.width - s(20)
        anchors.verticalCenter: parent.verticalCenter

        elide: Text.ElideLeft
        textFormat: Text.PlainText

        text: phone.clip.clipFilter !== "" ? phone.clip.clipFilter + "_" : "Digite para buscar…"
        color: phone.clip.clipFilter !== "" ? phone.txt : phone.ov(0.28)
        font.family: phone.fontUi
        font.pixelSize: s(11.5)
      }
    }

    ListView {
      id: clipList

      x: s(8)
      y: s(110)
      width: s(264)
      height: s(172)

      clip: true
      boundsBehavior: Flickable.StopAtBounds

      model: phone.clip.clipFiltered

      Connections {
        target: phone.clip

        function onClipSelChanged() {
          if (phone.clip.clipSel >= 0)
            clipList.positionViewAtIndex(phone.clip.clipSel, ListView.Contain);
        }
      }

      delegate: Item {
        id: crow

        required property var modelData
        required property int index

        readonly property bool isSel: index === phone.clip.clipSel

        width: clipList.width
        height: modelData.isImage ? s(44) : s(26)

        Rectangle {
          visible: crow.isSel
          anchors.fill: parent
          anchors.bottomMargin: s(2)
          radius: s(4)
          color: phone.cSel
        }

        // miniatura
        Rectangle {
          visible: crow.modelData.isImage

          x: s(6)
          y: s(3)
          width: s(36)
          height: s(36)
          radius: s(4)

          color: phone.ov(0.1)
          clip: true

          Image {
            anchors.fill: parent

            source: phone.clip.clipThumbSrc(crow.modelData.id)
            sourceSize.width: s(72)
            sourceSize.height: s(72)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
          }
        }

        Text {
          x: crow.modelData.isImage ? s(50) : s(10)
          width: parent.width - x - s(8)
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -s(1)

          elide: Text.ElideRight
          textFormat: Text.PlainText

          text: crow.modelData.label
          color: crow.isSel ? phone.pink : phone.txt
          font.family: phone.fontUi
          font.bold: crow.isSel
          font.pixelSize: s(11.5)
        }

        MouseArea {
          anchors.fill: parent

          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onEntered: phone.clip.clipSel = crow.index
          onClicked: {
            phone.clip.clipSel = crow.index;
            phone.clip.clipCopy(crow.modelData);
          }
        }
      }
    }

    // vazio / erro (fora do ListView para não rolar junto)
    Text {
      visible: phone.clip.clipError === "" && phone.clip.clipFiltered.length === 0

      x: s(16)
      y: s(170)
      width: s(248)
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap

      text: phone.clip.clipEntries.length === 0
        ? "Nada copiado ainda."
        : "Nada encontrado para “" + phone.clip.clipFilter + "”."
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    Text {
      visible: phone.clip.clipError !== ""

      x: s(16)
      y: s(140)
      width: s(248)
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      maximumLineCount: 6
      elide: Text.ElideRight

      text: phone.clip.clipError
      color: phone.ring
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }

    Text {
      x: s(10)
      y: s(292) - height / 2
      width: s(260)

      elide: Text.ElideRight
      textFormat: Text.PlainText

      text: phone.clip.clipStatus !== "" ? phone.clip.clipStatus : "Enter copia · → vê · Esc limpa"
      color: phone.clip.clipStatus !== "" ? phone.cOk : phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(10.5)
    }
  }

  // ---------------- ver ----------------

  Item {
    visible: phone.clip.clipStage === "preview"
    anchors.fill: parent

    Rectangle {
      x: s(8)
      y: s(78)
      width: s(264)
      height: s(200)
      radius: s(6)

      color: phone.ov(0.07)
      clip: true

      Image {
        visible: phone.clip.clipCurrent !== null && phone.clip.clipCurrent.isImage

        anchors.fill: parent
        anchors.margins: s(6)

        source: phone.clip.clipCurrent ? phone.clip.clipThumbSrc(phone.clip.clipCurrent.id) : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false
      }

      Text {
        visible: phone.clip.clipCurrent !== null && !phone.clip.clipCurrent.isImage

        anchors.fill: parent
        anchors.margins: s(8)

        wrapMode: Text.WrapAnywhere
        elide: Text.ElideRight
        textFormat: Text.PlainText

        text: phone.clip.clipPreviewText
        color: phone.txt
        font.family: phone.fontMono
        font.pixelSize: s(10.5)
      }
    }

    Text {
      x: s(10)
      y: s(292) - height / 2
      width: s(260)

      elide: Text.ElideRight
      textFormat: Text.PlainText

      text: phone.clip.clipStatus !== "" ? phone.clip.clipStatus : "↑↓ troca de item · Enter copia"
      color: phone.clip.clipStatus !== "" ? phone.cOk : phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(10.5)
    }
  }
}
