// views/ShareView.qml — VISÃO 7 — COMPARTILHAR TELA

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: shareView

  visible: phone.view === "share"

  Text {
    x: s(10)
    y: s(46) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: "Compartilhar tela"
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  // monitor externo detectado
  Text {
    x: s(10)
    y: s(66) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.share.shareInfo
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(11)
  }

  // verificando
  Text {
    visible: phone.share.shareChecking && !phone.share.shareHasExt
    anchors.horizontalCenter: parent.horizontalCenter
    y: s(150)

    text: "Procurando telas..."
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(13)
  }

  // nenhuma tela externa
  Item {
    visible: !phone.share.shareChecking && !phone.share.shareHasExt

    x: 0
    y: s(96)
    width: lcd.width
    height: s(190)

    Glyph {
      x: (parent.width - width) / 2
      y: s(10)
      width: s(56)
      height: s(56)

      kind: "screen"
      stroke: phone.cIconDim
      lw: 1.6
    }

    Text {
      x: s(24)
      y: s(88)
      width: parent.width - s(48)

      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap

      text: "Conecte uma tela externa ou projetor"
      color: phone.txt
      font.family: phone.fontUi
      font.pixelSize: s(15)
    }

    Text {
      x: s(24)
      y: s(138)
      width: parent.width - s(48)

      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap

      text: "Depois toque em Atualizar."
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }
  }

  // pergunta do passo atual
  Text {
    visible: phone.share.shareHasExt && phone.share.shareStep !== "done"

    x: s(10)
    y: s(92) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text:
      phone.share.shareStep === "mode"
        ? "O que fazer com a tela externa?"
        : "Espelhar para qual uso?"

    color: phone.txt
    font.family: phone.fontUi
    font.pixelSize: s(13)
  }

  // opções
  Repeater {
    model: phone.share.shareHasExt ? phone.share.shareOpts : []

    Rectangle {
      id: scard

      required property var modelData
      required property int index

      readonly property bool isSel: index === phone.share.shareSel
      readonly property bool hasIcon: modelData.icon !== ""

      x: s(10)
      y: s(108 + index * 76)
      width: s(260)
      height: s(68)
      radius: s(8)

      color: isSel ? phone.cSel : phone.cCard
      border.color: isSel ? phone.pink : phone.cLine
      border.width: isSel ? Math.max(1.5, s(2)) : 1

      Glyph {
        visible: scard.hasIcon

        x: s(12)
        y: (parent.height - height) / 2
        width: s(26)
        height: s(26)

        kind: scard.modelData.icon
        stroke: scard.isSel ? phone.pink : phone.cIcon
      }

      Text {
        x: scard.hasIcon ? s(50) : s(14)
        y: s(12)
        width: parent.width - x - s(10)

        elide: Text.ElideRight

        text: scard.modelData.t
        color: phone.txt
        font.family: phone.fontUi
        font.bold: true
        font.pixelSize: s(15)
      }

      Text {
        x: scard.hasIcon ? s(50) : s(14)
        y: s(34)
        width: parent.width - x - s(10)

        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight

        text: scard.modelData.d
        color: phone.txtMuted
        font.family: phone.fontUi
        font.pixelSize: s(11)
      }

      MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: phone.share.shareSel = scard.index

        onClicked: {
          phone.share.shareSel = scard.index;
          phone.share.shareChoose();
        }
      }
    }
  }

  // aplicado
  Item {
    visible: phone.share.shareStep === "done"

    x: 0
    y: s(96)
    width: lcd.width
    height: s(190)

    Glyph {
      x: (parent.width - width) / 2
      y: s(14)
      width: s(48)
      height: s(48)

      kind: "check"
      stroke: phone.pink
      lw: 2.4
    }

    Text {
      x: s(20)
      y: s(80)
      width: parent.width - s(40)

      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap

      text: phone.share.shareStatus
      color: phone.txt
      font.family: phone.fontUi
      font.pixelSize: s(14)
    }

    Text {
      x: s(20)
      y: s(140)
      width: parent.width - s(40)

      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap

      text: "Voltar para escolher outra opção."
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }
  }
}
