
 // views/NewsView.qml — VISÃO — NOTÍCIAS RSS

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: newsView

  visible: phone.view === "news"

  // ---------------- cabeçalho ----------------

  Text {
    x: s(10)
    y: s(46) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.news.newsTitle
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  Text {
    x: s(10)
    y: s(66) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.news.newsSubtitle
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(11)
  }

  // =================================================
  // LISTA
  // =================================================

  Item {
    visible: phone.news.newsStage === "list"
    anchors.fill: parent

    // ---------------- abas ----------------

    Row {
      x: s(8)
      y: s(78)

      width: s(264)
      height: s(26)

      spacing: s(4)

      Repeater {
        model: phone.news.newsTabs

        delegate: Rectangle {
          required property string modelData
          required property int index

          width: s(130)
          height: s(26)

          radius: s(4)

          color: phone.news.newsTab === index
            ? phone.cSel
            : phone.ov(0.05)

          border.width: phone.news.newsTab === index ? 1 : 0
          border.color: phone.pink

          Text {
            anchors.centerIn: parent

            text: parent.modelData
              + " (" + phone.news.newsCount(parent.index) + ")"

            color: phone.news.newsTab === parent.index
              ? phone.pink
              : phone.txtMuted

            font.family: phone.fontUi
            font.pixelSize: s(11.5)
            font.bold: phone.news.newsTab === parent.index
          }

          MouseArea {
            anchors.fill: parent

            cursorShape: Qt.PointingHandCursor

            onClicked: phone.news.newsSetTab(index)
          }
        }
      }
    }

    // ---------------- lista de notícias ----------------

    ListView {
      id: newsListView

      x: s(8)
      y: s(110)

      width: s(264)
      height: s(174)

      clip: true

      boundsBehavior: Flickable.StopAtBounds

      model: phone.news.newsList

      currentIndex: phone.news.newsSel

      Connections {
        target: phone.news

        function onNewsSelChanged() {
          if (phone.news.newsSel >= 0)
            newsListView.positionViewAtIndex(
              phone.news.newsSel,
              ListView.Contain
            );
        }
      }

      delegate: Item {
        id: newsRow

        required property var modelData
        required property int index

        readonly property bool isSelected:
          index === phone.news.newsSel

        width: newsListView.width
        height: s(52)

        // seleção

        Rectangle {
          visible: newsRow.isSelected

          anchors.fill: parent
          anchors.bottomMargin: s(2)

          radius: s(4)

          color: phone.cSel
        }

        // marcador

        Rectangle {
          x: s(5)
          y: s(8)

          width: s(3)
          height: s(36)

          radius: s(2)

          color: newsRow.isSelected
            ? phone.pink
            : phone.hair
        }

        // título

        Text {
          x: s(14)
          y: s(5)

          width: parent.width - s(22)

          elide: Text.ElideRight
          maximumLineCount: 2

          textFormat: Text.PlainText

          text: newsRow.modelData.titulo || "Sem título"

          color: newsRow.isSelected
            ? phone.pink
            : phone.txt

          font.family: phone.fontUi
          font.bold: newsRow.isSelected
          font.pixelSize: s(11.5)
        }

        // fonte e data

        Text {
          x: s(14)
          y: s(34)

          width: parent.width - s(22)

          elide: Text.ElideRight

          text: newsRow.modelData.fonte
            + (newsRow.modelData.data
              ? " · " + phone.news.ageText(newsRow.modelData.data)
              : "")

          color: phone.txtMuted

          font.family: phone.fontUi
          font.pixelSize: s(9.5)
        }

        MouseArea {
          anchors.fill: parent

          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onEntered: phone.news.newsSel = newsRow.index

          onClicked: {
            phone.news.newsSel = newsRow.index;
            phone.news.newsRead();
          }
        }
      }
    }

    // ---------------- vazio ----------------

    Text {
      visible: !phone.news.newsLoading
        && phone.news.newsError === ""
        && phone.news.newsList.length === 0

      x: s(16)
      y: s(158)

      width: s(248)

      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap

      text: "Nenhuma notícia nesta aba.\nPressione Atualizar para buscar."

      color: phone.txtMuted

      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    // ---------------- carregando ----------------

    Text {
      visible: phone.news.newsLoading
        && phone.news.newsList.length === 0

      x: s(16)
      y: s(158)

      width: s(248)

      horizontalAlignment: Text.AlignHCenter

      text: "Buscando notícias…"

      color: phone.pink

      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    // ---------------- erro ----------------

    Text {
      visible: phone.news.newsError !== ""

      x: s(16)
      y: s(140)

      width: s(248)

      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap

      maximumLineCount: 6
      elide: Text.ElideRight

      text: phone.news.newsError

      color: phone.ring

      font.family: phone.fontUi
      font.pixelSize: s(11)
    }
  }

  // =================================================
  // DETALHES
  // =================================================

  Item {
    visible: phone.news.newsStage === "detail"
    anchors.fill: parent

    // cartão da notícia

    Rectangle {
      x: s(8)
      y: s(78)

      width: s(264)
      height: s(204)

      radius: s(6)

      color: phone.ov(0.06)

      border.width: 1
      border.color: phone.hair

      clip: true

      // título

      Text {
        x: s(10)
        y: s(8)

        width: parent.width - s(20)
        height: s(48)

        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight

        textFormat: Text.PlainText

        text: phone.news.newsCurrent
          ? phone.news.newsCurrent.titulo
          : ""

        color: phone.txt

        font.family: phone.fontUi
        font.bold: true
        font.pixelSize: s(12.5)
      }

      // separador

      Rectangle {
        x: s(10)
        y: s(60)

        width: parent.width - s(20)
        height: 1

        color: phone.hair
      }

      // resumo rolável

      Flickable {
        id: newsSummaryFlick

        x: s(10)
        y: s(68)

        width: parent.width - s(20)
        height: s(108)

        clip: true

        contentWidth: width
        contentHeight: newsSummary.height

        boundsBehavior: Flickable.StopAtBounds

        Text {
          id: newsSummary

          width: newsSummaryFlick.width

          wrapMode: Text.WordWrap

          textFormat: Text.PlainText

          text: phone.news.newsCurrent
            ? phone.news.newsCurrent.resumo
            : "Resumo indisponível."

          color: phone.txt

          font.family: phone.fontUi
          font.pixelSize: s(11)

          lineHeight: 1.2
        }
      }

      // fonte

      Text {
        x: s(10)
        y: s(180)

        width: parent.width - s(20)

        elide: Text.ElideRight

        text: phone.news.newsCurrent
          ? phone.news.newsCurrent.fonte
          : ""

        color: phone.txtMuted

        font.family: phone.fontUi
        font.pixelSize: s(10)
      }
    }

    // aviso da ação

    Text {
      x: s(10)
      y: s(292) - height / 2

      width: s(260)

      elide: Text.ElideRight

      text: phone.news.newsNote

      color: phone.cOk

      font.family: phone.fontUi
      font.pixelSize: s(10.5)
    }
  }

  // =================================================
  // RODAPÉ
  // =================================================

  Rectangle {
    x: s(6)
    y: s(303)

    width: lcd.width - s(12)
    height: 1

    color: phone.hair
  }

  Text {
    x: s(10)
    y: s(314.5) - height / 2

    text: phone.news.newsSoftLeft

    color: phone.txt

    font.family: phone.fontUi
    font.pixelSize: s(13)

    MouseArea {
      anchors.fill: parent
      anchors.margins: -s(6)

      cursorShape: Qt.PointingHandCursor

      onClicked: phone.news.newsLeftKey()
    }
  }

  Text {
    x: (lcd.width - width) / 2
    y: s(314.5) - height / 2

    text: phone.news.newsSoftCenter

    color: phone.txt

    font.family: phone.fontUi
    font.pixelSize: s(13)

    MouseArea {
      anchors.fill: parent
      anchors.margins: -s(6)

      cursorShape: Qt.PointingHandCursor

      onClicked: phone.news.newsCenterKey()
    }
  }

  Text {
    x: s(270) - width
    y: s(314.5) - height / 2

    text: phone.news.newsSoftRight

    color: phone.txt

    font.family: phone.fontUi
    font.pixelSize: s(13)

    MouseArea {
      anchors.fill: parent
      anchors.margins: -s(6)

      cursorShape: Qt.PointingHandCursor

      onClicked: phone.news.newsBack()
    }
  }
}

