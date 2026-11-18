// apps/chat/ChatView.qml — Chat entre aparelhos (socket TCP)
//
// Tela de configuração (Ouvir / Conectar, IP, porta) e depois a conversa.
// Lógica: ChatApp.qml

import QtQuick
import "../../ui"

ViewBase {
  id: chatView

  visible: phone.view === "chat"

  readonly property var c: phone.chat

  Text {
    x: s(10)
    y: s(46) - height / 2

    text: "Chat"
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  Text {
    x: s(10)
    y: s(66) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: c.chatStatus
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(11)
  }

  // ================================================================
  // CONFIGURAÇÃO
  // ================================================================

  // linha 0: modo
  Rectangle {
    visible: c.chatScreen === "setup"

    x: s(8)
    y: s(96)
    width: s(264)
    height: s(28)
    radius: s(6)

    color: c.chatRow === 0 ? phone.cSel : phone.ov(0.07)

    Text {
      x: s(10)
      anchors.verticalCenter: parent.verticalCenter

      text: "Modo"
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: s(10)
      anchors.verticalCenter: parent.verticalCenter

      text: c.chatMode === "listen" ? "‹ Ouvir ›" : "‹ Conectar ›"
      color: phone.txt
      font.family: phone.fontUi
      font.pixelSize: s(12.5)
    }
  }

  // linha 1: IP do outro aparelho (só no modo Conectar)
  Rectangle {
    visible: c.chatScreen === "setup"

    x: s(8)
    y: s(130)
    width: s(264)
    height: s(28)
    radius: s(6)

    color: c.chatRow === 1 ? phone.cSel : phone.ov(0.07)
    opacity: c.chatMode === "connect" ? 1 : 0.4

    Text {
      x: s(10)
      anchors.verticalCenter: parent.verticalCenter

      text: "IP"
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    Text {
      x: s(60)
      width: parent.width - s(70)
      anchors.verticalCenter: parent.verticalCenter

      elide: Text.ElideLeft
      horizontalAlignment: Text.AlignRight

      text: c.chatMode === "listen"
        ? "não usado"
        : (c.chatHost === "" ? "ex: 192.168.0.12" : c.chatHost) + (c.chatRow === 1 ? "_" : "")
      color: c.chatHost === "" && c.chatMode === "connect" ? phone.ov(0.3) : phone.txt
      font.family: phone.fontUi
      font.pixelSize: s(12.5)
    }
  }

  // linha 2: porta
  Rectangle {
    visible: c.chatScreen === "setup"

    x: s(8)
    y: s(164)
    width: s(264)
    height: s(28)
    radius: s(6)

    color: c.chatRow === 2 ? phone.cSel : phone.ov(0.07)

    Text {
      x: s(10)
      anchors.verticalCenter: parent.verticalCenter

      text: "Porta"
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: s(10)
      anchors.verticalCenter: parent.verticalCenter

      text: c.chatPort + (c.chatRow === 2 ? "_" : "")
      color: phone.txt
      font.family: phone.fontUi
      font.pixelSize: s(12.5)
    }
  }

  // linha 3: iniciar
  Rectangle {
    visible: c.chatScreen === "setup"

    x: s(8)
    y: s(198)
    width: s(264)
    height: s(28)
    radius: s(6)

    color: c.chatRow === 3 ? phone.cSel : phone.ov(0.07)

    Text {
      anchors.centerIn: parent

      text: "Iniciar"
      color: phone.pink
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(13)
    }
  }

  Text {
    visible: c.chatScreen === "setup"

    x: s(16)
    y: s(236)
    width: s(248)

    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap

    text: c.chatMode === "listen"
      ? "No outro aparelho escolha Conectar e digite o IP mostrado no status acima."
      : "Setas escolhem o campo, Enter inicia. O outro aparelho precisa estar em Ouvir."
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(10.5)
  }

  // ================================================================
  // CONVERSA
  // ================================================================

  ListView {
    id: msgList

    visible: c.chatScreen === "chat"

    x: s(8)
    y: s(74)
    width: s(264)
    height: s(172)

    clip: true
    spacing: s(6)
    boundsBehavior: Flickable.StopAtBounds

    model: c.chatModel

    // acompanha a última mensagem
    onCountChanged: Qt.callLater(function () {
      msgList.positionViewAtEnd();
    })

    delegate: Item {
      id: linha

      required property int index
      required property string who
      required property string txt

      readonly property bool mine: linha.who === "me"
      readonly property bool sistema: linha.who === "sys"

      width: msgList.width
      height: bolha.height

      Rectangle {
        id: bolha

        anchors.right: linha.mine ? parent.right : undefined
        anchors.left: linha.mine || linha.sistema ? undefined : parent.left
        anchors.horizontalCenter: linha.sistema ? parent.horizontalCenter : undefined

        width: Math.min(linha.width * 0.8, Math.max(s(40), msgTxt.implicitWidth + s(20)))
        height: msgTxt.height + s(14)
        radius: s(8)

        color: linha.mine ? phone.cSel : (linha.sistema ? phone.ov(0.03) : phone.ov(0.09))

        Text {
          id: msgTxt

          x: s(10)
          y: s(7)
          width: bolha.width - s(20)

          wrapMode: Text.WordWrap
          horizontalAlignment: linha.sistema ? Text.AlignHCenter : Text.AlignLeft

          text: linha.txt
          color: linha.sistema ? phone.txtMuted : phone.txt
          font.family: phone.fontUi
          font.italic: linha.sistema
          font.pixelSize: linha.sistema ? s(10.5) : s(12.5)
        }
      }
    }

  }

  // lista vazia (fora da ListView, para não rolar junto com as mensagens)
  Text {
    visible: c.chatScreen === "chat" && msgList.count === 0

    x: msgList.x + s(10)
    y: msgList.y + msgList.height / 2 - height / 2
    width: msgList.width - s(20)

    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap

    text: "Sem mensagens ainda.\nDigite e aperte Enter."
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(12)
  }

  // ---------------- entrada ----------------

  Rectangle {
    visible: c.chatScreen === "chat"

    x: s(8)
    y: s(270)
    width: s(264)
    height: s(28)
    radius: s(6)

    color: phone.ov(0.09)
    opacity: c.chatConnected ? 1 : 0.5

    Text {
      x: s(9)
      anchors.verticalCenter: parent.verticalCenter

      text: "\u203A"
      color: phone.pink
      font.family: phone.fontUi
      font.pixelSize: s(15)
    }

    Text {
      x: s(22)
      width: parent.width - s(30)
      anchors.verticalCenter: parent.verticalCenter

      elide: Text.ElideLeft

      text: c.chatInput + (c.chatConnected ? "_" : "")
      color: phone.txt
      font.family: phone.fontUi
      font.pixelSize: s(12.5)
    }

    Text {
      visible: c.chatInput === ""

      x: s(22)
      anchors.verticalCenter: parent.verticalCenter

      text: c.chatConnected ? "Escreva uma mensagem" : "sem conexão"
      color: phone.ov(0.3)
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }
  }
}
