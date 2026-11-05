// views/SettingsView.qml — VISÃO 10 — CONFIGURAÇÕES

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: setView

  visible: phone.view === "settings"

  Text {
    x: s(10)
    y: s(46) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.config.setTitles[phone.config.setPage] || "Configurações"
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  Text {
    x: s(10)
    y: s(66) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.config.setStatus !== "" ? phone.config.setStatus : (phone.config.setHints[phone.config.setPage] || "")
    color: phone.config.setStatus.indexOf("Falhou") === 0 ? phone.ring : phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(11)
  }

  // barrinha de progresso enquanto um comando roda
  Rectangle {
    visible: phone.config.setBusy

    x: s(8)
    y: s(73)
    width: s(264)
    height: s(2)
    radius: height / 2
    color: phone.ov(0.10)
    clip: true

    Rectangle {
      width: s(60)
      height: parent.height
      radius: height / 2
      color: phone.pink

      NumberAnimation on x {
        running: phone.config.setBusy && phone.panelOpen
        loops: Animation.Infinite
        from: -s(60)
        to: s(264)
        duration: 1000
        easing.type: Easing.InOutQuad
      }
    }
  }

  // ---------------- cabeçalho: bateria ----------------

  Item {
    visible: phone.config.setPage === "battery"

    x: s(10)
    y: s(78)
    width: s(252)
    height: s(52)

    Text {
      text: phone.sys.batPct >= 0 ? phone.sys.batPct + "%" : "--"
      color: phone.sys.batPct >= 0 && phone.sys.batPct <= 15 && phone.sys.batState !== "Charging" ? phone.ring : phone.txt
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(30)
    }

    Text {
      anchors.right: parent.right
      y: s(10)

      text: phone.sys.batState === "Charging" ? "Carregando"
        : (phone.sys.batState === "Full" ? "Carga completa" : "Na bateria")
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    Rectangle {
      y: s(42)
      width: parent.width
      height: s(8)
      radius: height / 2
      color: phone.cCardHi

      Rectangle {
        width: parent.width * Math.max(0, phone.sys.batPct) / 100
        height: parent.height
        radius: height / 2

        color: phone.sys.batState === "Charging" ? phone.cOk
          : (phone.sys.batPct <= 15 ? phone.ring : phone.pink)
      }
    }
  }

  // ---------------- cabeçalho: telas ----------------

  Rectangle {
    visible: phone.config.setPage === "screens"

    x: s(8)
    y: s(78)
    width: s(264)
    height: s(84)
    radius: s(8)

    color: phone.cCard
    border.width: 1
    border.color: phone.cLine

    Text {
      visible: phone.config.setMonRects.length === 0
      anchors.centerIn: parent

      text: "Sem informações das telas"
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }

    Item {
      x: s(8)
      y: s(7)
      width: s(248)
      height: s(70)

      Repeater {
        model: phone.config.setMonRects

        delegate: Rectangle {
          required property var modelData

          x: modelData.x
          y: modelData.y
          width: Math.max(s(14), modelData.w - s(2))
          height: Math.max(s(10), modelData.h - s(2))
          radius: s(3)
          clip: true

          color: modelData.focused ? phone.cSel : phone.cCardHi
          border.width: 1
          border.color: modelData.focused ? phone.pink : phone.cIcon

          Column {
            anchors.centerIn: parent
            width: parent.width - s(6)

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight

              text: modelData.name
              color: phone.txt
              font.family: phone.fontUi
              font.bold: true
              font.pixelSize: s(10)
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight

              text: modelData.res + (modelData.mir !== "" ? " + espelho" : "")
              color: phone.txtMuted
              font.family: phone.fontUi
              font.pixelSize: s(9)
            }
          }
        }
      }
    }
  }

  // ---------------- cabeçalho: temas ----------------

  Item {
    visible: phone.config.setPage === "theme"

    x: s(8)
    y: s(78)
    width: s(264)
    height: s(54)

    Repeater {
      model: [
        { dark: true,  label: "Escuro", bg: "#1a2736", fg: "#e8edf2", ac: "#e8a0a8" },
        { dark: false, label: "Claro",  bg: "#f1f5f9", fg: "#1b2733", ac: "#c0455f" }
      ]

      delegate: Rectangle {
        required property var modelData

        readonly property bool picked: phone.themeDark === modelData.dark

        x: modelData.dark ? 0 : s(136)
        width: s(128)
        height: s(52)
        radius: s(8)

        color: modelData.bg
        border.width: picked ? 2 : 1
        border.color: picked ? phone.pink : phone.cLine

        Rectangle {
          x: s(10)
          y: s(10)
          width: s(36)
          height: s(6)
          radius: height / 2
          color: modelData.ac
        }

        Rectangle {
          x: s(10)
          y: s(21)
          width: s(60)
          height: s(4)
          radius: height / 2
          color: modelData.fg
          opacity: 0.45
        }

        Text {
          x: s(10)
          y: s(30)

          text: modelData.label
          color: modelData.fg
          font.family: phone.fontUi
          font.bold: true
          font.pixelSize: s(12)
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor

          onClicked: {
            phone.themeDark = modelData.dark;
            phone.config.setSave();
          }
        }
      }
    }
  }

  // ---------------- cabeçalho: sobre ----------------

  Item {
    visible: phone.config.setPage === "about"

    x: s(10)
    y: s(78)
    width: s(252)
    height: s(54)

    Rectangle {
      width: s(52)
      height: s(52)

      color: phone.cCard2
      border.color: phone.cLine
      border.width: 1
      clip: true

      Text {
        anchors.centerIn: parent

        text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
        color: phone.txtMuted
        font.family: phone.fontUi
        font.bold: true
        font.pixelSize: s(22)
      }

      Image {
        anchors.fill: parent
        anchors.margins: 1

        source: phone.photoSource + "?r=" + phone.files.photoRev
        cache: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
      }
    }

    Text {
      x: s(62)
      y: s(6)
      width: parent.width - s(62)

      elide: Text.ElideRight

      text: Quickshell.env("USER")
      color: phone.txt
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(17)
    }

    Text {
      x: s(62)
      y: s(30)
      width: parent.width - s(62)

      elide: Text.ElideRight

      text: phone.config.setAbout.host ? "@ " + phone.config.setAbout.host : ""
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }
  }

  // ---------------- lista ----------------

  ListView {
    id: setList

    // avisa a lógica qual é este item (usado para rolar)
    Binding { target: phone.config; property: "setListRef"; value: setList }

    x: s(8)
    y: s(76) + phone.config.setHeaderH
    width: s(264)
    height: s(224) - phone.config.setHeaderH

    clip: true
    boundsBehavior: Flickable.StopAtBounds

    model: phone.config.setRows

    delegate: Item {
      id: srowx

      required property var modelData
      required property int index

      readonly property bool isSel: index === phone.config.setSel
      readonly property bool isInfo: modelData.kind === "info"
      readonly property bool hasIcon:
        (modelData.icon || "") !== "" || modelData.kind === "net" || modelData.kind === "dev"

      width: setList.width
      height: s(34)

      Rectangle {
        visible: srowx.isSel
        anchors.fill: parent
        radius: s(5)
        color: phone.cSel
      }

      // ícone colorido das seções
      Rectangle {
        visible: (srowx.modelData.icon || "") !== ""

        x: s(5)
        anchors.verticalCenter: parent.verticalCenter
        width: s(24)
        height: s(24)
        radius: s(6)
        color: srowx.modelData.ic || "transparent"

        Glyph {
          anchors.centerIn: parent
          width: s(15)
          height: s(15)

          kind: srowx.modelData.icon || ""
          stroke: "white"
          lw: 2.2
        }
      }

      Glyph {
        visible: srowx.modelData.kind === "net"

        x: s(7)
        anchors.verticalCenter: parent.verticalCenter
        width: s(18)
        height: s(18)

        kind: "wifi"
        lw: 2.4
        stroke: srowx.modelData.on ? phone.pink : phone.cIcon
        opacity: 0.35 + 0.65 * Math.min(1, (srowx.modelData.sig || 0) / 70)
      }

      Glyph {
        visible: srowx.modelData.kind === "dev"

        x: s(8)
        anchors.verticalCenter: parent.verticalCenter
        width: s(16)
        height: s(16)

        kind: "bluetooth"
        lw: 2.2
        stroke: srowx.modelData.on ? "#6cb4ff" : phone.cIcon
      }

      Text {
        x: srowx.hasIcon ? s(38) : s(10)
        y: (srowx.modelData.d || "") !== ""
          ? (srowx.isInfo ? s(3) : s(4))
          : (parent.height - height) / 2
        width: parent.width - x - s(46)

        elide: Text.ElideRight

        text: srowx.modelData.t
        color: srowx.isInfo ? phone.txtMuted : (srowx.isSel ? phone.pink : phone.txt)
        font.family: phone.fontUi
        font.pixelSize: srowx.isInfo ? s(10) : s(12.5)
      }

      Text {
        visible: (srowx.modelData.d || "") !== ""

        x: srowx.hasIcon ? s(38) : s(10)
        y: srowx.isInfo ? s(16) : s(19)
        width: parent.width - x - s(46)

        elide: Text.ElideRight

        text: srowx.modelData.d || ""
        color: srowx.isInfo ? phone.txt : phone.txtMuted
        font.family: phone.fontUi
        font.pixelSize: srowx.isInfo ? s(12) : s(10)
      }

      // interruptor
      Rectangle {
        visible: srowx.modelData.kind === "toggle"

        x: parent.width - width - s(8)
        anchors.verticalCenter: parent.verticalCenter
        width: s(30)
        height: s(16)
        radius: height / 2
        color: srowx.modelData.on ? phone.pink : phone.cDim

        Rectangle {
          x: srowx.modelData.on ? parent.width - width - s(2) : s(2)
          anchors.verticalCenter: parent.verticalCenter
          width: s(12)
          height: s(12)
          radius: width / 2
          color: "white"
        }
      }

      // escolha única
      Rectangle {
        visible: srowx.modelData.kind === "radio"

        x: parent.width - width - s(10)
        anchors.verticalCenter: parent.verticalCenter
        width: s(15)
        height: s(15)
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: srowx.modelData.on ? phone.pink : phone.cIcon

        Rectangle {
          visible: srowx.modelData.on === true
          anchors.centerIn: parent
          width: s(7)
          height: s(7)
          radius: width / 2
          color: phone.pink
        }
      }

      // seta
      Text {
        visible: srowx.modelData.kind === "nav"

        x: parent.width - width - s(10)
        anchors.verticalCenter: parent.verticalCenter

        text: "\u203A"
        color: phone.txtMuted
        font.family: phone.fontUi
        font.pixelSize: s(16)
      }

      // conectado
      Rectangle {
        visible: (srowx.modelData.kind === "net" || srowx.modelData.kind === "dev") && srowx.modelData.on === true

        x: parent.width - width - s(12)
        anchors.verticalCenter: parent.verticalCenter
        width: s(8)
        height: s(8)
        radius: width / 2
        color: phone.cOk
      }

      MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        cursorShape: srowx.isInfo ? Qt.ArrowCursor : Qt.PointingHandCursor

        onEntered: phone.config.setSel = srowx.index

        onClicked: {
          phone.config.setSel = srowx.index;

          if (!srowx.isInfo)
            phone.config.setActivate();
        }
      }
    }
  }

  // ---------------- formulário (senha, ponto de acesso) ----------------

  Rectangle {
    visible: phone.config.setForm

    x: s(8)
    y: s(84)
    width: s(264)
    height: s(52) + phone.config.setFormFields.length * s(38) + s(28)
    radius: s(8)

    color: phone.cPop
    border.color: phone.pink
    border.width: 1

    Text {
      x: s(12)
      y: s(9)
      width: parent.width - s(24)

      elide: Text.ElideRight

      text: phone.config.setFormTitle
      color: phone.pink
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(14)
    }

    Repeater {
      model: phone.config.setFormFields

      delegate: Rectangle {
        required property var modelData
        required property int index

        readonly property bool on: index === phone.config.setFormFocus

        x: s(12)
        y: s(34) + index * s(38)
        width: s(240)
        height: s(32)
        radius: s(5)

        color: on ? phone.cSel : phone.ov(0.07)
        border.width: on ? 1 : 0
        border.color: phone.pink

        Text {
          x: s(9)
          width: s(50)
          anchors.verticalCenter: parent.verticalCenter

          text: modelData.label
          color: phone.txtMuted
          font.family: phone.fontUi
          font.pixelSize: s(11)
        }

        Text {
          x: s(60)
          width: parent.width - s(68)
          anchors.verticalCenter: parent.verticalCenter

          elide: Text.ElideLeft

          text: (modelData.mask
            ? "\u2022".repeat(modelData.value.length)
            : modelData.value) + (on ? "_" : "")

          color: phone.txt
          font.family: phone.fontUi
          font.pixelSize: s(13)
        }

        MouseArea {
          anchors.fill: parent
          onClicked: phone.config.setFormFocus = index
        }
      }
    }

    Text {
      x: s(12)
      y: s(40) + phone.config.setFormFields.length * s(38) - s(4)
      width: parent.width - s(24)

      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight

      text: phone.config.setFormHint
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(10)
    }
  }

  // ---------------- aviso / QR Code (por cima de tudo) ----------------

  Rectangle {
    visible: phone.config.setCardOn

    x: s(8)
    y: s(80)
    width: s(264)
    height: phone.config.setCardImage !== ""
      ? s(236)
      : setCardBodyText.implicitHeight + s(62)
    radius: s(8)

    color: phone.cPop
    border.color: phone.pink
    border.width: 1

    Text {
      x: s(12)
      y: s(10)
      width: parent.width - s(24)

      elide: Text.ElideRight

      text: phone.config.setCardTitle
      color: phone.pink
      font.family: phone.fontUi
      font.bold: true
      font.pixelSize: s(14)
    }

    // QR Code (fundo branco: precisa de contraste pra câmera ler)
    Rectangle {
      visible: phone.config.setCardImage !== ""

      x: (parent.width - width) / 2
      y: s(36)
      width: s(150)
      height: s(150)
      color: "white"

      Image {
        anchors.fill: parent
        anchors.margins: s(4)

        source: phone.config.setCardImage !== "" ? "file://" + phone.config.setCardImage + "?r=" + phone.config.setCardRev : ""
        cache: false
        fillMode: Image.PreserveAspectFit
        smooth: false
      }
    }

    Text {
      id: setCardBodyText

      visible: phone.config.setCardImage === ""

      x: s(12)
      y: s(34)
      width: parent.width - s(24)

      wrapMode: Text.WordWrap
      maximumLineCount: 10
      elide: Text.ElideRight

      text: phone.config.setCardBody
      color: phone.txt
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }

    Text {
      x: s(12)
      y: parent.height - height - s(8)
      width: parent.width - s(24)

      elide: Text.ElideRight

      text: phone.config.setCardImage !== ""
        ? phone.config.hotspotSsid + " · aponte a câmera do celular"
        : "Qualquer tecla fecha"
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(10.5)
    }

    MouseArea {
      anchors.fill: parent
      onClicked: phone.config.setCardClose()
    }
  }
}
