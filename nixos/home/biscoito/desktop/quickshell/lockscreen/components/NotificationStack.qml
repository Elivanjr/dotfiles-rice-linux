import QtQuick
import QtQuick.Layouts

Column {
    id: stack
    property var bridge
    property string fontFamily: "sans-serif"
    property color accentColor: "#4dabf7"
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.leftMargin: 20
    anchors.topMargin: 54
    width: 340
    spacing: 10

    Repeater {
        model: stack.bridge ? stack.bridge.notifications : []
        delegate: Rectangle {
            id: card
            required property var modelData
            width: stack.width
            implicitHeight: content.implicitHeight + 24
            radius: 14; color: "#cc17171b"; border.color: "#22ffffff"; border.width: 1
            MouseArea { anchors.fill: parent; onClicked: stack.bridge.dismiss(card.modelData.id) }
            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 10
                Rectangle {
                    visible: stack.bridge.iconUrl(card.modelData.image) !== "" || stack.bridge.iconUrl(card.modelData.appIcon) !== ""
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 6; color: "#33000000"; clip: true
                    Image { anchors.fill: parent; source: stack.bridge.iconUrl(card.modelData.image) || stack.bridge.iconUrl(card.modelData.appIcon); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                }
                ColumnLayout {
                    id: content; Layout.fillWidth: true; spacing: 2
                    Text { text: card.modelData.appName || "Sistema"; color: stack.accentColor; font.family: stack.fontFamily; font.pixelSize: 10; Layout.fillWidth: true }
                    Text { text: card.modelData.summary || ""; color: "white"; font.family: stack.fontFamily; font.bold: true; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    Text { visible: (card.modelData.body || "") !== ""; text: card.modelData.body || ""; color: "#bbbbbb"; font.family: stack.fontFamily; font.pixelSize: 10; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }
        }
    }
}
