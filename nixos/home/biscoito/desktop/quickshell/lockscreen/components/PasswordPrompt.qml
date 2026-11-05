import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pam

Column {
    id: prompt
    property string fontFamily: "sans-serif"
    property color accentColor: "#4dabf7"
    signal authenticated()
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 8

    Rectangle {
        width: 300; height: 52; radius: height / 2; color: "#cc1a1a1e"
        border.color: field.activeFocus ? prompt.accentColor : "#33ffffff"; border.width: 2
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 14; spacing: 10
            Text { text: ""; font.pixelSize: 16; font.family: prompt.fontFamily; color: "#aaaaaa" }
            Item { Layout.fillWidth: true; Layout.fillHeight: true
                TextInput {
                    id: field; anchors.fill: parent; verticalAlignment: TextInput.AlignVCenter; echoMode: TextInput.Password
                    color: "white"; font.pixelSize: 16; font.family: prompt.fontFamily; enabled: !pam.active; focus: true; clip: true
                    onAccepted: pam.start(); Keys.onEscapePressed: text = ""
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: pam.active ? "Verificando..." : "Password..."; color: "#88ffffff"; font.pixelSize: 16; font.family: prompt.fontFamily; visible: field.text.length === 0 }
            }
            Text { text: "\u2328"; font.pixelSize: 16; font.family: prompt.fontFamily; color: "#888888" }
            Text { text: "\u21B5"; font.pixelSize: 18; font.family: prompt.fontFamily; color: prompt.accentColor
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: pam.start() }
            }
        }
    }
    Text { id: feedback; anchors.horizontalCenter: parent.horizontalCenter; color: "#ff6b6b"; font.family: prompt.fontFamily; visible: text.length > 0 }
    PamContext {
        id: pam; config: "login"
        onResponseRequiredChanged: if (responseRequired) respond(field.text)
        onCompleted: (result) => {
            if (result === PamResult.Success) prompt.authenticated()
            else { feedback.text = "Senha incorreta"; field.text = "" }
        }
        onError: (error) => feedback.text = "Erro no PAM: " + error
    }
}
