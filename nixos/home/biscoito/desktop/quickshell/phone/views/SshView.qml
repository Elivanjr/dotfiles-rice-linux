// views/SshView.qml — VISÃO 8 — SSH (túnel + pastas + terminal)

import QtQuick
import Quickshell
import "../ui"

ViewBase {
  id: sshView

  visible: phone.view === "ssh"

  Text {
    x: s(10)
    y: s(46) - height / 2
    width: s(260)

    elide: Text.ElideRight

    text: phone.ssh.sshTitle
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(21)
  }

  Text {
    x: s(10)
    y: s(66) - height / 2
    width: s(260)

    elide: Text.ElideLeft

    text: phone.ssh.sshSubtitle
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(11)
  }

  // ---------------- 1. formulário ----------------

  Item {
    visible: phone.ssh.sshStage === "form"
    anchors.fill: parent

    Repeater {
      model: phone.ssh.sshLabels

      Rectangle {
        required property string modelData
        required property int index

        readonly property bool on: index === phone.ssh.sshFocus
        readonly property string val: phone.ssh.sshFields[index]

        x: s(8)
        y: s(78) + index * s(36)
        width: s(264)
        height: s(32)
        radius: s(5)

        color: on ? phone.cSel : phone.ov(0.07)
        border.width: on ? 1 : 0
        border.color: phone.pink

        Text {
          x: s(10)
          width: s(88)
          anchors.verticalCenter: parent.verticalCenter

          elide: Text.ElideRight

          text: modelData
          color: phone.txtMuted
          font.family: phone.fontUi
          font.pixelSize: s(11)
        }

        Text {
          x: s(96)
          width: parent.width - s(104)
          anchors.verticalCenter: parent.verticalCenter

          elide: Text.ElideLeft

          text: val + (on ? "_" : "")
          color: phone.txt
          font.family: phone.fontUi
          font.pixelSize: s(13)
        }

        Text {
          visible: val === "" && !on

          x: s(96)
          width: parent.width - s(104)
          anchors.verticalCenter: parent.verticalCenter

          elide: Text.ElideRight

          text: phone.ssh.sshHints[index]
          color: phone.ov(0.28)
          font.family: phone.fontUi
          font.pixelSize: s(12)
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.IBeamCursor

          onClicked: phone.ssh.sshFocus = index
        }
      }
    }

    // parâmetros fixos da tunel_ssh (só o IP muda)
    Rectangle {
      x: s(8)
      y: s(120)
      width: s(264)
      height: s(84)
      radius: s(6)
      color: phone.ov(0.05)

      Column {
        x: s(12)
        y: s(8)
        width: s(240)
        spacing: s(4)

        Repeater {
          model: [
            { k: "Usuário", v: phone.ssh.sshUser },
            { k: "SSH",     v: "porta " + phone.ssh.sshDest + " no Termux" },
            { k: "Local",   v: "localhost:" + phone.ssh.sshLocal },
            { k: "Chave",   v: "~/.ssh/termux_maya" }
          ]

          Item {
            required property var modelData

            width: s(240)
            height: s(16)

            Text {
              width: s(56)
              anchors.verticalCenter: parent.verticalCenter

              text: modelData.k
              color: phone.txtMuted
              font.family: phone.fontUi
              font.pixelSize: s(11)
            }

            Text {
              x: s(56)
              width: parent.width - s(56)
              anchors.verticalCenter: parent.verticalCenter

              elide: Text.ElideRight

              text: modelData.v
              color: phone.txt
              font.family: phone.fontUi
              font.pixelSize: s(11.5)
            }
          }
        }
      }
    }

    Text {
      visible: phone.ssh.sshMsg === ""

      x: s(10)
      y: s(212)
      width: s(260)

      wrapMode: Text.WordWrap

      text: "Digite o IP do Termux na rede atual e abra o túnel. A autenticação é pela chave SSH."
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(10.5)
    }

    Text {
      visible: phone.ssh.sshMsg !== ""

      x: s(10)
      y: s(212)
      width: s(260)

      wrapMode: Text.WordWrap
      maximumLineCount: 6
      elide: Text.ElideRight

      text: phone.ssh.sshMsg
      color: phone.ring
      font.family: phone.fontUi
      font.pixelSize: s(10.5)
    }
  }

  // ---------------- 2/3/4. túnel, pronto, autenticando ----------------

  Item {
    visible:
      phone.ssh.sshStage === "tunnel"
      || phone.ssh.sshStage === "ready"
      || (phone.ssh.sshStage === "browser" && !phone.ssh.sshShellUp)

    anchors.fill: parent

    // barra "indeterminada" enquanto espera
    Rectangle {
      visible: phone.ssh.sshWaiting

      x: s(8)
      y: s(78)
      width: s(264)
      height: s(3)
      radius: height / 2
      color: phone.ov(0.10)
      clip: true

      Rectangle {
        y: 0
        width: s(70)
        height: parent.height
        radius: height / 2
        color: phone.pink

        NumberAnimation on x {
          running: phone.ssh.sshWaiting && phone.panelOpen
          loops: Animation.Infinite
          from: -s(70)
          to: s(264)
          duration: 1100
          easing.type: Easing.InOutQuad
        }
      }
    }

    Rectangle {
      x: s(8)
      y: s(88)
      width: s(264)
      height: s(80)
      radius: s(6)
      color: phone.ov(0.07)

      Column {
        x: s(12)
        y: s(9)
        width: s(240)
        spacing: s(6)

        Repeater {
          model: [
            { k: "Local",   v: "localhost:" + phone.ssh.sshLocal },
            { k: "Termux",  v: phone.ssh.sshHost + ":" + phone.ssh.sshDest },
            { k: "Login",   v: phone.ssh.sshTarget }
          ]

          Item {
            required property var modelData

            width: s(240)
            height: s(18)

            Text {
              width: s(62)
              anchors.verticalCenter: parent.verticalCenter

              text: modelData.k
              color: phone.txtMuted
              font.family: phone.fontUi
              font.pixelSize: s(11)
            }

            Text {
              x: s(62)
              width: parent.width - s(62)
              anchors.verticalCenter: parent.verticalCenter

              elide: Text.ElideRight

              text: modelData.v
              color: phone.txt
              font.family: phone.fontUi
              font.bold: true
              font.pixelSize: s(12)
            }
          }
        }
      }
    }

    Rectangle {
      visible: !phone.ssh.sshReadyErr

      x: s(8)
      y: s(176)
      width: s(264)
      height: s(46)
      radius: s(6)
      color: phone.cPop

      Text {
        anchors.fill: parent
        anchors.margins: s(7)

        wrapMode: Text.WrapAnywhere
        maximumLineCount: 3
        elide: Text.ElideRight

        text: "$ " + phone.ssh.sshTunnelCmd
        color: phone.cOk
        font.family: phone.fontMono
        font.pixelSize: s(10)
      }
    }

    Text {
      visible: !phone.ssh.sshReadyErr

      x: s(10)
      y: s(230)
      width: s(260)

      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight

      text: phone.ssh.sshStage === "ready"
        ? "Conectar via SSH em " + phone.ssh.sshUser + "@" + phone.ssh.sshHost + "?"
        : (phone.ssh.sshStage === "tunnel"
            ? "Abrindo o túnel com a chave…"
            : "Autenticando com a chave…")

      color: phone.ssh.sshStage === "ready" ? phone.txt : phone.txtMuted
      font.family: phone.fontUi
      font.bold: phone.ssh.sshStage === "ready"
      font.pixelSize: phone.ssh.sshStage === "ready" ? s(13) : s(11)
    }

    Text {
      visible: phone.ssh.sshReadyErr

      x: s(10)
      y: s(180)
      width: s(260)

      wrapMode: Text.WordWrap
      maximumLineCount: 8
      elide: Text.ElideRight

      text: phone.ssh.sshMsg
      color: phone.ring
      font.family: phone.fontUi
      font.pixelSize: s(10.5)
    }
  }

  // ---------------- 5. sessão: pastas / terminal ----------------

  Item {
    visible: phone.ssh.sshStage === "browser" && phone.ssh.sshShellUp
    anchors.fill: parent

    // ----- pastas -----

    ListView {
      id: sshList

      // avisa a lógica qual é este item (usado para rolar)
      Binding { target: phone.ssh; property: "sshListRef"; value: sshList }

      visible: phone.ssh.sshMode === "files"

      x: s(8)
      y: s(78)
      width: s(264)
      height: s(194)

      clip: true
      boundsBehavior: Flickable.StopAtBounds

      model: phone.ssh.sshFileModel

      delegate: Item {
        id: srow

        required property string fname
        required property bool isDir
        required property bool marked
        required property int index

        readonly property bool isSel: index === phone.ssh.sshSel

        width: sshList.width
        height: s(26)

        Rectangle {
          visible: srow.isSel
          anchors.fill: parent
          radius: s(4)
          color: phone.cSel
        }

        Glyph {
          x: s(8)
          y: (parent.height - height) / 2
          width: s(16)
          height: s(16)

          kind: srow.marked ? "check" : (srow.isDir ? "folder" : "file")
          stroke: srow.marked ? phone.pink : (srow.isDir ? "#e8c25a" : phone.cIcon)
        }

        Text {
          x: s(32)
          width: parent.width - s(32) - s(24)
          anchors.verticalCenter: parent.verticalCenter

          elide: Text.ElideMiddle

          text: srow.fname
          color: srow.marked ? phone.pink : phone.txt
          font.family: phone.fontUi
          font.bold: srow.marked
          font.pixelSize: s(13)
        }

        Text {
          x: parent.width - width - s(8)
          anchors.verticalCenter: parent.verticalCenter

          text: (srow.isDir && srow.fname !== "..") ? "\u203A" : ""
          color: phone.txtMuted
          font.family: phone.fontUi
          font.pixelSize: s(12)
        }

        MouseArea {
          anchors.fill: parent

          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onEntered: phone.ssh.sshSel = srow.index

          onClicked: {
            phone.ssh.sshSel = srow.index;
            phone.ssh.sshActivate();
          }
        }
      }

    }

    // avisos fora do ListView (filho dele rolaria junto com o conteúdo)
    Text {
      visible:
        phone.ssh.sshMode === "files"
        && phone.ssh.sshListError === ""
        && phone.ssh.sshFileModel.count <= (phone.ssh.sshCwd !== "/" ? 1 : 0)

      x: s(8)
      y: s(180)
      width: s(264)
      horizontalAlignment: Text.AlignHCenter

      text: phone.ssh.sshHidden ? "Pasta vazia" : "Pasta vazia (sem ocultos)"
      color: phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    Text {
      visible: phone.ssh.sshMode === "files" && phone.ssh.sshListError !== ""

      x: s(8)
      y: s(180)
      width: s(264)
      horizontalAlignment: Text.AlignHCenter

      text: phone.ssh.sshListError
      color: phone.ring
      font.family: phone.fontUi
      font.pixelSize: s(12)
    }

    Text {
      visible: phone.ssh.sshMode === "files"

      x: s(10)
      y: s(285) - height / 2
      width: s(260)

      elide: Text.ElideRight

      text:
        phone.ssh.sshStatus !== ""
          ? phone.ssh.sshStatus
          : (phone.ssh.sshMarked > 0
              ? phone.ssh.sshMarked + " marcado(s) · Opções > Baixar"
              : "Enter abre pasta ou marca arquivo")

      color: phone.ssh.sshStatus.indexOf("Falha") === 0 ? phone.ring : phone.txtMuted
      font.family: phone.fontUi
      font.pixelSize: s(11)
    }

    // ----- terminal -----

    Item {
      visible: phone.ssh.sshMode === "term"
      anchors.fill: parent

      ListView {
        id: sshTermList

        // avisa a lógica qual é este item (usado para rolar)
        Binding { target: phone.ssh; property: "sshTermListRef"; value: sshTermList }

        x: s(8)
        y: s(76)
        width: s(264)
        height: s(194)

        clip: true
        boundsBehavior: Flickable.StopAtBounds

        model: phone.ssh.sshTermModel

        onCountChanged: {
          if (phone.ssh.sshStick)
            Qt.callLater(function () { sshTermList.positionViewAtEnd(); });
        }

        onMovementEnded: phone.ssh.sshStick = sshTermList.atYEnd

        delegate: Text {
          required property string kind
          required property string txt

          width: sshTermList.width

          text: txt === "" ? " " : txt
          textFormat: Text.PlainText
          wrapMode: Text.WrapAnywhere

          font.family: phone.fontMono
          font.pixelSize: s(10.5)

          color:
            kind === "cmd" ? phone.pink
              : kind === "err" ? phone.ring
              : kind === "sys" ? phone.txtMuted
              : phone.cCode
        }
      }

      Rectangle {
        x: s(8)
        y: s(276)
        width: s(264)
        height: s(22)
        radius: s(5)
        color: phone.ov(0.09)

        Text {
          x: s(8)
          anchors.verticalCenter: parent.verticalCenter

          text: phone.ssh.sshBusy > 0 ? "…" : "$"
          color: phone.pink
          font.family: phone.fontMono
          font.pixelSize: s(12)
        }

        Text {
          x: s(22)
          width: parent.width - s(30)
          anchors.verticalCenter: parent.verticalCenter

          elide: Text.ElideLeft

          text: phone.ssh.sshInput + "_"
          color: phone.txt
          font.family: phone.fontMono
          font.pixelSize: s(12)
        }
      }
    }
  }
}
