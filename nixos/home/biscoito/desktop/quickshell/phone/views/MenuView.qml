// views/MenuView.qml — VISÃO 1 — MENU

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: menuView

  visible: phone.view === "menu"

  // título: app selecionado (ou busca)
  Text {
    x: s(10)
    y: s(46) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.menu.query === ""
      ? phone.menu.selectedName
      : phone.menu.query + "_"

    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  // roda do mouse troca de linha
  MouseArea {
    x: 0
    y: s(60)
    width: lcd.width
    height: s(230)

    acceptedButtons: Qt.NoButton

    onWheel: function (w) {
      phone.menu.move(w.angleDelta.y > 0 ? -4 : 4);
    }
  }

  // grade 4x4
  Repeater {
    model:
      phone.menu.menuItems.slice(
        phone.menu.page * phone.menu.perPage,
        phone.menu.page * phone.menu.perPage + phone.menu.perPage
      )

    Item {
      id: cell

      required property var modelData
      required property int index

      readonly property int globalIndex:
        phone.menu.page * phone.menu.perPage + index

      readonly property bool isSel:
        globalIndex === phone.menu.selected

      readonly property string iconUrl:
        modelData.music ? "" : phone.menu.resolveIcon(modelData.icon)

      width: s(67)
      height: s(56)

      x: s(40 + (index % 4) * 67.33) - width / 2
      y: s(89 + Math.floor(index / 4) * 56.33) - height / 2

      // anel de seleção
      Rectangle {
        visible: cell.isSel
        anchors.centerIn: parent
        width: s(50)
        height: s(50)
        radius: width / 2

        color: phone.ov(0.04)
        border.color: phone.ring
        border.width: Math.max(1.5, s(2))
      }

      Item {
        anchors.centerIn: parent
        width: s(31)
        height: s(31)

        // Música: círculo rosa com nota branca
        Rectangle {
          visible: modelData.music === true
          anchors.fill: parent
          radius: width / 2
          color: phone.noteBg

          Glyph {
            anchors.centerIn: parent
            width: s(19)
            height: s(19)
            kind: "note"
            stroke: "white"
          }
        }

        // Notícias: quadrado azul com documento
        Rectangle {
          visible: modelData.news === true
          anchors.fill: parent
          radius: s(6)
          color: "#397bb8"

          Glyph {
            anchors.centerIn: parent
            width: s(21)
            height: s(21)
            kind: "file"
            stroke: "white"
          }
        }

        // Wallpaper: quadrado amarelo com paisagem
        Rectangle {
          visible: modelData.wallpaper === true
          anchors.fill: parent
          radius: s(6)
          color: "#e8c25a"

          Glyph {
            anchors.centerIn: parent
            width: s(21)
            height: s(21)
            kind: "image"
            stroke: "#2a3340"
          }
        }

        // Meus arquivos: quadrado azul com pasta branca
        Rectangle {
          visible: modelData.files === true
          anchors.fill: parent
          radius: s(6)
          color: "#4a9fe0"

          Glyph {
            anchors.centerIn: parent
            width: s(21)
            height: s(21)
            kind: "folder"
            stroke: "white"
          }
        }

        // Foco: quadrado vermelho-tomate com cronômetro
        Rectangle {
          visible: modelData.foco === true
          anchors.fill: parent
          radius: s(6)
          color: "#e0554a"

          Glyph {
            anchors.centerIn: parent
            width: s(21)
            height: s(21)
            kind: "timer"
            stroke: "white"
          }
        }

        // Calculadora: quadrado verde-água
        Rectangle {
          visible: modelData.calc === true
          anchors.fill: parent
          radius: s(6)
          color: "#2fa4a0"

          Glyph {
            anchors.centerIn: parent
            width: s(21)
            height: s(21)
            kind: "calc"
            stroke: "white"
          }
        }

        // Configurações: quadrado cinza-azulado com engrenagem
        Rectangle {
          visible: modelData.settings === true
          anchors.fill: parent
          radius: s(6)
          color: "#6b7d8f"

          Glyph {
            anchors.centerIn: parent
            width: s(21)
            height: s(21)
            kind: "gear"
            stroke: "white"
          }
        }

        // IA: quadrado laranja com balão de conversa
        Rectangle {
          visible: modelData.ai === true
          anchors.fill: parent
          radius: s(6)
          color: "#e08a3c"

          Glyph {
            anchors.centerIn: parent
            width: s(21)
            height: s(21)
            kind: "chat"
            stroke: "white"
          }
        }

        // SSH: quadrado verde com terminal
        Rectangle {
          visible: modelData.ssh === true
          anchors.fill: parent
          radius: s(6)
          color: "#3f9a77"

          Glyph {
            anchors.centerIn: parent
            width: s(21)
            height: s(21)
            kind: "terminal"
            stroke: "white"
          }
        }

        // Agendar: quadrado roxo com calendário
        Rectangle {
          visible: modelData.sched === true
          anchors.fill: parent
          radius: s(6)
          color: "#8a6fd1"

          Glyph {
            anchors.centerIn: parent
            width: s(21)
            height: s(21)
            kind: "calendar"
            stroke: "white"
          }
        }

        // Baixar: quadrado verde-água com a seta de download
        Rectangle {
          visible: modelData.dl === true
          anchors.fill: parent
          radius: s(6)
          color: "#2f9e8f"

          Glyph {
            anchors.centerIn: parent
            width: s(21)
            height: s(21)
            kind: "download"
            stroke: "white"
          }
        }

        // Clipboard: quadrado laranja com a prancheta
        Rectangle {
          visible: modelData.clip === true
          anchors.fill: parent
          radius: s(6)
          color: "#d9822b"

          Glyph {
            anchors.centerIn: parent
            width: s(21)
            height: s(21)
            kind: "clipboard"
            stroke: "white"
          }
        }

        // Terminal: quadrado escuro com o prompt >_
        Rectangle {
          visible: modelData.term === true
          anchors.fill: parent
          radius: s(6)
          color: "#2b3038"

          Text {
            anchors.centerIn: parent

            text: ">_"
            color: "#7ee787"
            font.family: phone.fontMono
            font.bold: true
            font.pixelSize: s(14)
          }
        }

        // Cobrinha: quadrado verde com a cobra
        Rectangle {
          visible: modelData.snake === true
          anchors.fill: parent
          radius: s(6)
          color: "#4f9b5b"

          Glyph {
            anchors.centerIn: parent
            width: s(21)
            height: s(21)
            kind: "snake"
            stroke: "white"
          }
        }

        Image {
          id: appIcon

          anchors.fill: parent
          visible: status === Image.Ready

          source: cell.iconUrl
          sourceSize.width: 64
          sourceSize.height: 64
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
        }

        // sem ícone: círculo com a inicial
        Rectangle {
          visible:
            modelData.music !== true &&
            modelData.news !== true &&
            modelData.wallpaper !== true &&
            modelData.files !== true &&
            modelData.foco !== true &&
            modelData.settings !== true &&
            modelData.ssh !== true &&
            modelData.ai !== true &&
            modelData.calc !== true &&
            modelData.term !== true &&
            modelData.sched !== true &&
            modelData.dl !== true &&
            modelData.clip !== true &&
            modelData.snake !== true &&
            appIcon.status !== Image.Ready

          anchors.fill: parent
          radius: width / 2
          color: phone.cTile

          Text {
            anchors.centerIn: parent

            text: (modelData.name || "?").charAt(0).toUpperCase()
            color: phone.txt
            font.family: phone.fontUi
            font.bold: true
            font.pixelSize: s(15)
          }
        }
      }

      MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: phone.menu.selected = cell.globalIndex
        onClicked: phone.menu.launch(cell.modelData)
      }
    }
  }

  // bolinhas de página
  Row {
    visible: phone.menu.pageCount > 1

    x: (lcd.width - width) / 2
    y: s(292) - height / 2
    spacing: s(5)

    Repeater {
      model: phone.menu.pageCount

      Rectangle {
        required property int index

        width: s(4)
        height: s(4)
        radius: width / 2

        color: index === phone.menu.page ? phone.cDotOn : phone.cDot
      }
    }
  }

  Text {
    visible: phone.menu.menuItems.length === 0
    anchors.horizontalCenter: parent.horizontalCenter
    y: s(150)

    text: "Nenhum app encontrado"
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(14)
  }
}
