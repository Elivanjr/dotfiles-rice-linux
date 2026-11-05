// views/AiView.qml — VISÃO 9 — IA (chat com o Ollama)

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: aiView

  visible: phone.view === "ai"

  // espaço que a linha de anexos tira da conversa
  readonly property real attachH: phone.ai.aiAttachModel.count > 0 || phone.ai.aiAttachProc.running ? s(22) : 0

  Text {
    x: s(10)
    y: s(46) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: "IA"
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  Text {
    x: s(10)
    y: s(66) - height / 2
    width: s(260)

    elide: Text.ElideMiddle

    text: phone.ai.aiSubtitle
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(11)
  }

  // ---------------- estado vazio ----------------

  Text {
    visible: phone.ai.aiChatModel.count === 0

    x: s(16)
    y: s(110)
    width: s(248)

    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap

    text: !phone.ai.aiServerUp
      ? "Não encontrei o Ollama em\n" + phone.ai.aiBase
      : (phone.ai.aiModel !== ""
          ? "Converse com " + phone.ai.aiModel + "\n\nDigite e aperte Enter."
          : "Nenhum modelo instalado.\nUse `ollama pull <modelo>`.")

    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(13)
  }

  // ---------------- conversa ----------------

  Flickable {
    id: aiFlick

    // avisa a lógica qual é este item (usado para rolar)
    Binding { target: phone.ai; property: "aiFlickRef"; value: aiFlick }

    x: s(8)
    y: s(74)
    width: s(264)
    height: s(172) - aiView.attachH

    contentWidth: width
    contentHeight: aiCol.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    // acompanha o fim enquanto a resposta cresce; se rolar pra cima, solta
    onContentHeightChanged: {
      if (phone.ai.aiStick)
        phone.ai.aiScrollEnd();
    }

    onContentYChanged: {
      if (!phone.ai.aiAutoScroll)
        phone.ai.aiStick = (aiFlick.contentY + aiFlick.height >= aiFlick.contentHeight - 8);
    }

    Column {
      id: aiCol

      width: aiFlick.width - s(6)
      spacing: s(8)

      Repeater {
        model: phone.ai.aiChatModel

        delegate: Item {
          id: arow

          required property int index
          required property string role
          required property string content
          required property string stats
          required property string images
          required property string files

          readonly property var imgList: arow.images !== "" ? JSON.parse(arow.images) : []
          readonly property var fileList: arow.files !== "" ? JSON.parse(arow.files) : []
          readonly property real thumbsW: arow.imgList.length > 0 ? arow.imgList.length * s(40) - s(4) : 0
          readonly property real chipsW: arow.fileList.length > 0 ? s(120) : 0

          readonly property bool isUser: arow.role === "user"
          readonly property bool isLast: arow.index === phone.ai.aiChatModel.count - 1
          readonly property bool streaming: phone.ai.aiBusy && arow.isLast

          // trechos: texto (Markdown) e blocos de código
          readonly property var segs: arow.isUser
            ? phone.ai.aiUserSegs(arow.content)
            : phone.ai.aiParseSegments(arow.content)

          width: aiCol.width
          height: abubble.height + (afoot.visible ? afoot.height + s(2) : 0)

          // mede o texto sem quebra: o balão do usuário fica do tamanho da frase
          Text {
            id: aprobe

            visible: false
            text: arow.content
            wrapMode: Text.NoWrap
            font.family: phone.fontUi
            font.pixelSize: s(12)
          }

          Rectangle {
            id: abubble

            anchors.right: arow.isUser ? parent.right : undefined
            anchors.left: arow.isUser ? undefined : parent.left

            width: arow.isUser
              ? Math.min(arow.width * 0.92, Math.max(aprobe.implicitWidth, arow.thumbsW, arow.chipsW) + s(20))
              : arow.width

            height: Math.max(s(26), abubbleCol.height + s(14))
            radius: s(8)
            color: arow.isUser ? phone.cSel : phone.ov(0.07)

            Column {
              id: abubbleCol

              x: s(10)
              y: s(7)
              width: abubble.width - s(20)
              spacing: s(6)

              // miniaturas das imagens enviadas
              Flow {
                visible: arow.imgList.length > 0
                width: abubbleCol.width
                spacing: s(4)

                Repeater {
                  model: arow.imgList

                  delegate: Image {
                    required property string modelData

                    width: s(36)
                    height: s(36)
                    source: "file://" + modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 96
                    sourceSize.height: 96
                  }
                }
              }

              // arquivos de texto enviados
              Flow {
                visible: arow.fileList.length > 0
                width: abubbleCol.width
                spacing: s(4)

                Repeater {
                  model: arow.fileList

                  delegate: Rectangle {
                    required property var modelData

                    width: Math.min(abubbleCol.width, s(120))
                    height: s(20)
                    radius: s(5)
                    color: phone.ov(0.14)

                    Text {
                      x: s(8)
                      width: parent.width - s(16)
                      anchors.verticalCenter: parent.verticalCenter

                      elide: Text.ElideMiddle

                      text: modelData.name
                      color: phone.txt
                      font.family: phone.fontUi
                      font.pixelSize: s(10)
                    }
                  }
                }
              }

              // trechos de texto e de código
              Repeater {
                // o modelo é só o NÚMERO de trechos: os já criados são
                // atualizados no lugar enquanto a resposta chega
                model: arow.segs.length

                delegate: Item {
                  id: aseg

                  required property int index

                  readonly property string segType: (arow.segs[aseg.index] || {}).type || "text"
                  readonly property string segText: (arow.segs[aseg.index] || {}).text || ""
                  readonly property string segLang: (arow.segs[aseg.index] || {}).lang || ""
                  readonly property string segHtml: aseg.segType === "code"
                    ? phone.ai.aiHighlight(aseg.segText, aseg.segLang)
                    : ""

                  property bool copied: false

                  width: abubbleCol.width
                  height: aseg.segType === "code" ? acodeBox.height : aprose.contentHeight

                  // ---- texto ----
                  Text {
                    id: aprose

                    visible: aseg.segType !== "code"
                    width: parent.width

                    text: aseg.segType !== "code" ? aseg.segText : ""
                    textFormat: aseg.segType === "plain" ? Text.PlainText : Text.MarkdownText
                    wrapMode: Text.Wrap

                    color: phone.txt
                    font.family: phone.fontUi
                    font.pixelSize: s(12)

                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                  }

                  // ---- bloco de código ----
                  Rectangle {
                    id: acodeBox

                    visible: aseg.segType === "code"
                    width: parent.width
                    height: s(20) + acodeBody.contentHeight + s(10)
                    radius: s(6)

                    color: phone.cPop
                    border.width: 1
                    border.color: phone.ov(0.12)

                    Rectangle {
                      x: 1
                      y: 1
                      width: parent.width - 2
                      height: s(18)
                      radius: s(5)
                      color: phone.cPopHi

                      // quadrado embaixo: só o topo fica arredondado
                      Rectangle {
                        y: s(9)
                        width: parent.width
                        height: s(9)
                        color: parent.color
                      }

                      Text {
                        x: s(8)
                        anchors.verticalCenter: parent.verticalCenter

                        text: aseg.segLang !== "" ? aseg.segLang : "código"
                        color: phone.txtMuted
                        font.family: phone.fontUi
                        font.pixelSize: s(10)
                      }

                      Text {
                        anchors.right: parent.right
                        anchors.rightMargin: s(8)
                        anchors.verticalCenter: parent.verticalCenter

                        text: aseg.copied ? "copiado" : "copiar"
                        color: aseg.copied ? phone.cOk : phone.txtMuted
                        font.family: phone.fontUi
                        font.pixelSize: s(10)

                        MouseArea {
                          anchors.fill: parent
                          anchors.margins: -s(4)

                          cursorShape: Qt.PointingHandCursor

                          onClicked: {
                            Quickshell.execDetached(["wl-copy", "--", aseg.segText]);
                            aseg.copied = true;
                            acopyTimer.restart();
                          }
                        }
                      }
                    }

                    Text {
                      id: acodeBody

                      x: s(8)
                      y: s(22)
                      width: parent.width - s(16)

                      text: aseg.segHtml
                      textFormat: Text.RichText
                      wrapMode: Text.WrapAtWordBoundaryOrAnywhere

                      color: phone.cCode
                      font.family: phone.fontMono
                      font.pixelSize: s(10)
                    }
                  }

                  Timer {
                    id: acopyTimer

                    interval: 1500
                    onTriggered: aseg.copied = false
                  }
                }
              }
            }

            Text {
              visible: !arow.isUser && arow.content === "" && arow.streaming

              x: s(10)
              anchors.verticalCenter: parent.verticalCenter

              text: "pensando…"
              color: phone.txtMuted
              font.family: phone.fontUi
              font.pixelSize: s(12)
            }
          }

          // velocidade da resposta
          Text {
            id: afoot

            visible: !arow.isUser && arow.content !== "" && !arow.streaming && arow.stats !== ""

            anchors.top: abubble.bottom
            anchors.topMargin: s(2)
            x: s(4)

            text: arow.stats
            color: phone.txtMuted
            font.family: phone.fontUi
            font.pixelSize: s(9.5)
          }
        }
      }
    }
  }

  // barra de rolagem fininha
  Rectangle {
    visible: aiFlick.contentHeight > aiFlick.height

    x: s(8) + aiFlick.width - s(3)
    y: aiFlick.y + aiFlick.visibleArea.yPosition * aiFlick.height
    width: s(2.5)
    height: Math.max(s(18), aiFlick.visibleArea.heightRatio * aiFlick.height)
    radius: width / 2
    color: phone.txtMuted
    opacity: 0.5
  }

  // ---------------- aviso / erro (por cima do fim da conversa) ----------------

  Rectangle {
    visible: phone.ai.aiBanner !== ""

    x: s(8)
    y: aiFlick.y + aiFlick.height - height
    width: s(264)
    height: aiBannerText.implicitHeight + s(10)
    radius: s(6)

    color: phone.cWarn
    border.width: 1
    border.color: phone.ring

    Text {
      id: aiBannerText

      x: s(8)
      y: s(5)
      width: parent.width - s(16)

      wrapMode: Text.WordWrap
      maximumLineCount: 3
      elide: Text.ElideRight

      text: phone.ai.aiBanner
      color: phone.ring
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }

    MouseArea {
      anchors.fill: parent

      onClicked: {
        phone.ai.aiNotice = "";

        if (!phone.ai.aiTagsProc.running)
          phone.ai.aiTagsProc.running = true;
      }
    }
  }

  // ---------------- anexos pendentes ----------------

  Flow {
    visible: phone.ai.aiAttachModel.count > 0 || phone.ai.aiAttachProc.running

    x: s(8)
    y: s(248)
    width: s(264)
    spacing: s(4)

    Repeater {
      model: phone.ai.aiAttachModel

      delegate: Rectangle {
        id: achip

        required property int index
        required property string kind
        required property string path
        required property string name
        required property string trunc

        width: Math.min(s(120), achipRow.implicitWidth + s(12))
        height: s(18)
        radius: s(5)
        color: phone.ov(0.14)

        Row {
          id: achipRow

          x: s(6)
          anchors.verticalCenter: parent.verticalCenter
          spacing: s(4)

          Image {
            visible: achip.kind === "image"
            anchors.verticalCenter: parent.verticalCenter

            width: achip.kind === "image" ? s(14) : 0
            height: s(14)
            source: achip.kind === "image" ? "file://" + achip.path : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 48
            sourceSize.height: 48
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter

            text: (achip.kind === "image" ? "imagem" : achip.name) + (achip.trunc !== "" ? " (cortado)" : "") + "  ×"
            elide: Text.ElideMiddle
            width: Math.min(implicitWidth, s(96))

            color: phone.txt
            font.family: phone.fontUi
            font.pixelSize: s(10)
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor

          onClicked: phone.ai.aiRemoveAttachment(achip.index)
        }
      }
    }

    Rectangle {
      visible: phone.ai.aiAttachProc.running

      width: s(26)
      height: s(18)
      radius: s(5)
      color: phone.ov(0.08)

      Text {
        anchors.centerIn: parent

        text: "…"
        color: phone.txtMuted
        font.pixelSize: s(11)
      }
    }
  }

  // ---------------- entrada ----------------

  Rectangle {
    x: s(8)
    y: s(270)
    width: s(264)
    height: s(28)
    radius: s(6)

    color: phone.ov(0.09)
    opacity: phone.ai.aiModel !== "" && phone.ai.aiServerUp ? 1 : 0.5

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

      text: phone.ai.aiInput.replace(/\n/g, " \u21B5 ") + (phone.ai.aiBusy ? "" : "_")
      color: phone.ai.aiBusy ? phone.txtMuted : phone.txt
      font.family: phone.fontUi
      font.pixelSize: s(12.5)
    }

    Text {
      visible: phone.ai.aiInput === ""

      x: s(22)
      anchors.verticalCenter: parent.verticalCenter

      text: phone.ai.aiBusy ? "gerando…" : "Pergunte algo"
      color: phone.ov(0.3)
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }
  }
}
