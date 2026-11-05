import QtQuick

Row {
    property var status
    property string fontFamily: "sans-serif"
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 20
    spacing: 18

    Repeater {
        model: status ? [
            { icon: status.batteryIcon(), label: status.batteryPercent + "%" },
            { icon: "\uf1eb", label: status.wifiSsid },
            { icon: status.tempIcon(), label: status.tempCelsius + "°C" },
            { icon: status.volumeIcon(), label: status.volumePercent + "%" }
        ] : []
        delegate: Row {
            required property var modelData
            spacing: 6
            Text { text: modelData.icon; font.pixelSize: 15; font.family: fontFamily; color: "white" }
            Text { text: modelData.label; font.pixelSize: 14; font.family: fontFamily; color: "#dddddd" }
        }
    }
}
