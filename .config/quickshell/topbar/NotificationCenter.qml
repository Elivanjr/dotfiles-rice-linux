// NotificationCenter.qml — histórico de notificações do NotificationServer
// nativo do Quickshell (substitui o painel do SwayNC).
//
// Mostra dados copiados na hora que a notificação chegou (NotificationService.notifHistory
// no shell.qml) — nunca o objeto Notification vivo, então nada aqui quebra
// mesmo depois da notificação original expirar/ser dispensada.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

PanelWindow {
  id: notifCenter
  required property var screenRef
  screen: screenRef
  property bool panelOpen: false
  visible: panelOpen
  color: "transparent"
  focusable: true
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  signal closeRequested()

  // mesmo mapeamento do shell.qml: fundo de módulo = surface_container,
  // texto = source_color, destaque = primary, texto apagado = outline
  readonly property color colModBg: Colors.md3.surface_container
  readonly property color colText: Colors.md3.source_color
  readonly property color colMuted: Colors.md3.outline
  readonly property color colAccent: Colors.md3.primary

  // ---- módulo MPRIS — mesma prioridade Spotify > mpv da topbar ----
  readonly property var spotifyPlayer: {
    for (const p of Mpris.players.values) {
      if ((p.identity || "").toLowerCase().indexOf("spotify") !== -1) return p;
    }
    return null;
  }
  readonly property var mpvPlayer: {
    for (const p of Mpris.players.values) {
      if ((p.identity || "").toLowerCase().indexOf("mpv") !== -1) return p;
    }
    return null;
  }
  readonly property var mediaPlayer: spotifyPlayer || mpvPlayer

  // mesma lógica do NotificationToasts.qml — ver comentário lá pro porquê
  function resolveIcon(icon) {
    if (!icon || icon === "") return "";
    if (icon.startsWith("file://") || icon.startsWith("http://") || icon.startsWith("https://") || icon.startsWith("image://")) return icon;
    if (icon.startsWith("/")) return "file://" + icon;
    return Quickshell.iconPath(icon, "");
  }

  anchors { top: true; left: true }
  implicitWidth: 360
  implicitHeight: 460
  margins.top: 6
  margins.left: Math.round((screenRef.width - implicitWidth) / 2)

  onPanelOpenChanged: if (panelOpen) card.forceActiveFocus()

  Rectangle {
    id: card
    anchors.fill: parent
    radius: 16
    color: notifCenter.colModBg
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1

    focus: true
    Keys.onEscapePressed: notifCenter.closeRequested()

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 14
      spacing: 10

      // ---- cabeçalho: título + DND + apagar ----
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "Notificações"
          color: notifCenter.colText
          font.family: "JetBrainsMono NF"
          font.bold: true
          font.pixelSize: 13
          Layout.fillWidth: true
        }

        Rectangle {
          radius: 8
          color: NotificationService.dndEnabled
                 ? Qt.rgba(notifCenter.colAccent.r, notifCenter.colAccent.g, notifCenter.colAccent.b, 0.25)
                 : Qt.rgba(1, 1, 1, 0.06)
          implicitWidth: dndText.implicitWidth + 18
          implicitHeight: 26
          Text {
            id: dndText
            anchors.centerIn: parent
            text: NotificationService.dndEnabled ? "Não perturbe: ON" : "Não perturbe: OFF"
            color: NotificationService.dndEnabled ? notifCenter.colAccent : notifCenter.colMuted
            font.family: "JetBrainsMono NF"
            font.pixelSize: 10
          }
          MouseArea { anchors.fill: parent; onClicked: NotificationService.dndEnabled = !NotificationService.dndEnabled }
        }

        Rectangle {
          radius: 8
          color: Qt.rgba(1, 1, 1, 0.06)
          implicitWidth: clearText.implicitWidth + 18
          implicitHeight: 26
          Text {
            id: clearText
            anchors.centerIn: parent
            text: "Apagar"
            color: notifCenter.colAccent
            font.family: "JetBrainsMono NF"
            font.pixelSize: 10
          }
          MouseArea { anchors.fill: parent; onClicked: NotificationService.clearNotifHistory() }
        }
      }

      // ---- módulo MPRIS (Spotify > mpv, mesma prioridade da topbar) ----
      Rectangle {
        visible: notifCenter.mediaPlayer !== null
        Layout.fillWidth: true
        implicitHeight: mprisRow.implicitHeight + 20
        radius: 12
        color: Qt.rgba(0.56, 0.75, 0.42, 0.08)
        border.color: Qt.rgba(notifCenter.colAccent.r, notifCenter.colAccent.g, notifCenter.colAccent.b, 0.25)
        border.width: 1

        RowLayout {
          id: mprisRow
          anchors.fill: parent
          anchors.margins: 10
          spacing: 10

          Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: 8
            color: Qt.rgba(0, 0, 0, 0.3)
            clip: true
            Image {
              anchors.fill: parent
              source: notifCenter.mediaPlayer ? (notifCenter.mediaPlayer.trackArtUrl || "") : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
              text: notifCenter.mediaPlayer ? (notifCenter.mediaPlayer.trackTitle || "") : ""
              color: notifCenter.colText
              font.family: "JetBrainsMono NF"
              font.bold: true
              font.pixelSize: 12
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
            Text {
              text: notifCenter.mediaPlayer ? (notifCenter.mediaPlayer.trackArtist || "") : ""
              color: notifCenter.colMuted
              font.family: "JetBrainsMono NF"
              font.pixelSize: 10
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }

          RowLayout {
            spacing: 4
            Text {
              text: "\u{F048}"
              color: notifCenter.colText
              font.pixelSize: 13
              MouseArea { anchors.fill: parent; onClicked: if (notifCenter.mediaPlayer) notifCenter.mediaPlayer.previous() }
            }
            Text {
              text: (notifCenter.mediaPlayer && notifCenter.mediaPlayer.isPlaying) ? "\u{F04C}" : "\u{F04B}"
              color: notifCenter.colAccent
              font.pixelSize: 13
              MouseArea {
                anchors.fill: parent
                onClicked: if (notifCenter.mediaPlayer) notifCenter.mediaPlayer.isPlaying = !notifCenter.mediaPlayer.isPlaying
              }
            }
            Text {
              text: "\u{F051}"
              color: notifCenter.colText
              font.pixelSize: 13
              MouseArea { anchors.fill: parent; onClicked: if (notifCenter.mediaPlayer) notifCenter.mediaPlayer.next() }
            }
          }
        }
      }

      // ---- lista ----
      ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: NotificationService.notifHistory

        delegate: Rectangle {
          required property var modelData
          width: ListView.view.width
          implicitHeight: notifCol.implicitHeight + 16
          radius: 10
          color: Qt.rgba(1, 1, 1, 0.05)

          RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Rectangle {
              visible: notifCenter.resolveIcon(modelData.image) !== "" || notifCenter.resolveIcon(modelData.appIcon) !== ""
              Layout.preferredWidth: 32
              Layout.preferredHeight: 32
              radius: 6
              color: Qt.rgba(0, 0, 0, 0.3)
              clip: true
              Image {
                anchors.fill: parent
                source: notifCenter.resolveIcon(modelData.image) || notifCenter.resolveIcon(modelData.appIcon)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
              }
            }

            ColumnLayout {
              id: notifCol
              Layout.fillWidth: true
              spacing: 2

              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: modelData.appName
                  color: notifCenter.colAccent
                  font.family: "JetBrainsMono NF"
                  font.pixelSize: 10
                  Layout.fillWidth: true
                }
                Text {
                  text: modelData.time
                  color: notifCenter.colMuted
                  font.family: "JetBrainsMono NF"
                  font.pixelSize: 9
                }
              }
              Text {
                text: modelData.summary
                color: notifCenter.colText
                font.family: "JetBrainsMono NF"
                font.bold: true
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
              }
              Text {
                visible: modelData.body !== ""
                text: modelData.body
                color: notifCenter.colMuted
                font.family: "JetBrainsMono NF"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                maximumLineCount: 3
                elide: Text.ElideRight
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: NotificationService.notifHistory.length === 0
          text: "Sem notificações"
          color: notifCenter.colMuted
          font.family: "JetBrainsMono NF"
          font.pixelSize: 12
        }
      }
    }
  }
}
