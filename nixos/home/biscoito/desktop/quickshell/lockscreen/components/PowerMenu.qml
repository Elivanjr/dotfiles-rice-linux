import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pam

Item {
    id: control
    property string fontFamily: "sans-serif"
    property color accentColor: "#4dabf7"
    property bool menuOpen: false
    property bool confirmLogout: false
    anchors.fill: parent

    Process { id: shutdown; command: ["systemctl", "poweroff"] }
    Process { id: reboot; command: ["systemctl", "reboot"] }
    Process { id: logout; command: ["hyprctl", "dispatch", "exit"] }
    PamContext {
        id: pam
        config: "login"
        onResponseRequiredChanged: if (responseRequired) respond(password.text)
        onCompleted: (result) => {
            if (result === PamResult.Success) logout.running = true
            else { feedback.text = "Senha incorreta"; password.text = "" }
        }
        onError: (error) => feedback.text = "Erro no PAM: " + error
    }

    Rectangle {
        id: button
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 20
        width: 44; height: 44; radius: 22
        color: control.menuOpen ? control.accentColor : "#cc17171b"
        border.color: "#33ffffff"; border.width: 1
        Text { anchors.centerIn: parent; text: "\uf011"; font.pixelSize: 17; font.family: control.fontFamily; color: control.menuOpen ? "#101014" : "#dddddd" }
        MouseArea { anchors.fill: parent; onClicked: { control.menuOpen = !control.menuOpen; control.confirmLogout = false } }
    }

    Rectangle {
        visible: control.menuOpen
        anchors.bottom: button.top; anchors.right: button.right; anchors.bottomMargin: 10
        width: 220; radius: 14; color: "#e617171b"; border.color: "#22ffffff"; border.width: 1
        implicitHeight: content.implicitHeight + 24
        ColumnLayout {
            id: content
            anchors.fill: parent; anchors.margins: 12; spacing: 10
            PowerAction { visible: !control.confirmLogout; icon: "\uf011"; label: "Desligar"; iconColor: "#ff6b6b"; onClicked: { shutdown.running = true; control.menuOpen = false } }
            PowerAction { visible: !control.confirmLogout; icon: "\uf2f1"; label: "Reiniciar"; iconColor: control.accentColor; onClicked: { reboot.running = true; control.menuOpen = false } }
            PowerAction { visible: !control.confirmLogout; icon: "\uf2f5"; label: "Encerrar sessão"; iconColor: "#aed581"; onClicked: { control.confirmLogout = true; feedback.text = ""; password.text = ""; password.forceActiveFocus() } }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 6; visible: control.confirmLogout
                Text { text: "Confirme a senha:"; font.pixelSize: 12; font.family: control.fontFamily; color: "#dddddd" }
                Rectangle {
                    Layout.fillWidth: true; height: 34; radius: 8; color: "#33101014"; border.color: "#33ffffff"; border.width: 1
                    TextInput { id: password; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; verticalAlignment: TextInput.AlignVCenter; echoMode: TextInput.Password; color: "white"; font.pixelSize: 13; font.family: control.fontFamily; enabled: !pam.active; onAccepted: pam.start() }
                }
                Text { id: feedback; font.pixelSize: 11; font.family: control.fontFamily; color: "#ff6b6b"; visible: text.length > 0 }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Button { text: "Cancelar"; onClicked: { control.confirmLogout = false; control.menuOpen = false } }
                    Button { text: pam.active ? "..." : "Confirmar"; onClicked: pam.start() }
                }
            }
        }
    }

    component PowerAction: RowLayout {
        property string icon
        property string label
        property color iconColor
        signal clicked()
        Layout.fillWidth: true
        spacing: 10
        Text { text: parent.icon; font.pixelSize: 14; font.family: control.fontFamily; color: parent.iconColor }
        Text { text: parent.label; font.pixelSize: 13; font.family: control.fontFamily; color: "white"; Layout.fillWidth: true }
        TapHandler { onTapped: parent.clicked() }
    }
    component Button: Rectangle {
        property string text
        signal clicked()
        Layout.fillWidth: true; height: 28; radius: 6; color: text === "Confirmar" || text === "..." ? "#aed581" : "#33ffffff"
        Text { anchors.centerIn: parent; text: parent.text; font.pixelSize: 11; font.family: control.fontFamily; color: parent.text === "Confirmar" || parent.text === "..." ? "#101014" : "white" }
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }
}
