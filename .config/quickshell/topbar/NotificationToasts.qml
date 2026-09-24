// NotificationToasts.qml — popups de notificação nova, empilhados no topo
// centralizado da tela. Renderiza NotificationService.activeNotifications
// (objetos Notification vivos, mantidos e removidos pelo NotificationServer).
import QtQuick
import QtQuick.Layouts
import Quickshell

PanelWindow {
  id: toasts
  required property var screenRef
  screen: screenRef
  color: "transparent"

  anchors { top: true; left: true }
  implicitWidth: 340
  implicitHeight: Math.max(1, column.implicitHeight + 12)
  margins.top: 16
  margins.left: Math.round((screenRef.width - implicitWidth) / 2)

  // mesmo mapeamento do shell.qml/NotificationCenter
  readonly property color colModBg: Colors.md3.surface_container
  readonly property color colText: Colors.md3.source_color
  readonly property color colMuted: Colors.md3.outline
  readonly property color colAccent: Colors.md3.primary

  // resolve appIcon/image pro que o Image realmente consegue carregar:
  // path absoluto -> file://, já é URI -> usa direto, senão tenta resolver
  // como nome de ícone de tema via Quickshell.iconPath(). Um caminho
  // RELATIVO (ex: "Imagens/foo.jpg") não tem base confiável pra resolver —
  // isso é limitação do protocolo de notificação, não tem como adivinhar
  // a partir de qual diretório o app que notificou estava rodando.
  function resolveIcon(icon) {
    if (!icon || icon === "") return "";
    if (icon.startsWith("file://") || icon.startsWith("http://") || icon.startsWith("https://") || icon.startsWith("image://")) return icon;
    if (icon.startsWith("/")) return "file://" + icon;
    return Quickshell.iconPath(icon, "");
  }

  ColumnLayout {
    id: column
    anchors.top: parent.top
    anchors.left: parent.left
    width: parent.width
    spacing: 16

    // ---- toast especial "tocando agora" (só Spotify) ----
    // nota: cantos da capa não ficam realmente arredondados — "clip" do
    // QtQuick recorta em retângulo, não respeita "radius" (mesma limitação
    // já explicada no MediaPopup/ClipboardPanel; precisaria de
    // QtQuick.Effects, que não confirmei disponível aqui).
    Repeater {
      model: NotificationService.mediaToasts

      delegate: Rectangle {
        required property var modelData
        Layout.fillWidth: true
        implicitHeight: 96
        radius: 16
        color: toasts.colModBg
        border.color: Qt.rgba(toasts.colAccent.r, toasts.colAccent.g, toasts.colAccent.b, 0.3)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.margins: 8
          spacing: 16

          Item {
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80

            Rectangle {
              anchors.fill: parent
              radius: 16
              color: Qt.rgba(0, 0, 0, 0.35)
              Image {
                anchors.fill: parent
                source: modelData.artUrl || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
              }
            }

            // selo do player, sobreposto no canto inferior esquerdo da capa
            Rectangle {
              width: 22; height: 22; radius: 11
              anchors.left: parent.left
              anchors.bottom: parent.bottom
              anchors.leftMargin: -4
              anchors.bottomMargin: -4
              color: toasts.colModBg
              border.color: Qt.rgba(toasts.colAccent.r, toasts.colAccent.g, toasts.colAccent.b, 0.5)
              border.width: 1
              Text {
                anchors.centerIn: parent
                text: "\u{F04C7}" // spotify
                color: toasts.colAccent
                font.pixelSize: 11
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
              Layout.fillWidth: true
              Text {
                text: modelData.title || ""
                color: toasts.colText
                font.family: "JetBrainsMono NF"
                font.bold: true
                font.pixelSize: 14
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
              Text {
                text: "Now"
                color: toasts.colAccent
                font.family: "JetBrainsMono NF"
                font.pixelSize: 10
              }
            }
            Text {
              text: modelData.artist || ""
              color: toasts.colMuted
              font.family: "JetBrainsMono NF"
              font.pixelSize: 11
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }
        }
      }
    }

    Repeater {
      model: NotificationService.activeNotifications

      delegate: Rectangle {
        id: toastCard
        required property var modelData
        Layout.fillWidth: true
        implicitHeight: toastCol.implicitHeight + 28
        radius: 24
        color: toasts.colModBg
        border.color: Qt.rgba(toasts.colAccent.r, toasts.colAccent.g, toasts.colAccent.b, 0.25)
        border.width: 1

        MouseArea {
          anchors.fill: parent
          onClicked: NotificationService.dismissNotification(modelData)
        }

        RowLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 20

          Rectangle {
            visible: toasts.resolveIcon(modelData.image) !== "" || toasts.resolveIcon(modelData.appIcon) !== ""
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 6
            color: Qt.rgba(0, 0, 0, 0.3)
            clip: true
            Image {
              anchors.fill: parent
              source: toasts.resolveIcon(modelData.image) || toasts.resolveIcon(modelData.appIcon)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
            }
          }

          ColumnLayout {
            id: toastCol
            Layout.fillWidth: true
            spacing: 2

            Text {
              text: modelData.appName || "Sistema"
              color: toasts.colAccent
              font.family: "JetBrainsMono NF"
              font.pixelSize: 10
            }
            Text {
              text: modelData.summary || ""
              color: toasts.colText
              font.family: "JetBrainsMono NF"
              font.weight: Font.ExtraBold
              font.pixelSize: 14
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
            Text {
              visible: (modelData.body || "") !== ""
              text: modelData.body || ""
              color: toasts.colMuted
              font.family: "JetBrainsMono NF"
              font.pixelSize: 11
              wrapMode: Text.WordWrap
              maximumLineCount: 3
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            // ---- botões de ação (ex: "Sim"/"Não" do notify-send -A) ----
            RowLayout {
              visible: modelData.actions.length > 0
              Layout.fillWidth: true
              Layout.topMargin: 4
              spacing: 6

              Repeater {
                model: modelData.actions

                delegate: Rectangle {
                  id: actionBtn
                  required property var modelData
                  radius: 8
                  color: Qt.rgba(toasts.colAccent.r, toasts.colAccent.g, toasts.colAccent.b, 0.14)
                  implicitWidth: actionLabel.implicitWidth + 16
                  implicitHeight: 22

                  Text {
                    id: actionLabel
                    anchors.centerIn: parent
                    text: actionBtn.modelData.text
                    color: toasts.colAccent
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 10
                  }

                  MouseArea {
                    anchors.fill: parent
                    onClicked: {
                      actionBtn.modelData.invoke();
                      if (!toastCard.modelData.resident) NotificationService.dismissNotification(toastCard.modelData);
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
