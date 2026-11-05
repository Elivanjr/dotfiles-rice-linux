import QtQuick

Column {
    id: clock
    property string fontFamily: "sans-serif"
    property color accentColor: "#4dabf7"
    property string currentTime: ""
    property string currentDate: ""
    signal submitPassword(string password)
    spacing: 24

    Item { width: timeText.implicitWidth; height: 90; anchors.horizontalCenter: parent.horizontalCenter
        Text { id: timeText; anchors.centerIn: parent; text: clock.currentTime; color: "white"; font.pixelSize: 64; font.family: clock.fontFamily; font.letterSpacing: 2 }
    }
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: clock.currentDate; color: "#dddddd"; font.pixelSize: 20; font.family: clock.fontFamily }
}
