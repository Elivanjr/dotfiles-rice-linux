import QtQuick
import QtQuick.Effects
import "components" as Components
import "config" as Config
import "services" as Services
import "utils/DateFormat.js" as DateFormat

Rectangle {
    id: root

    signal unlocked()

    Config.Theme {
        id: theme
    }

    property color accentColor: theme.accentColor
    property string fontFamily: theme.fontFamily

    color: theme.backgroundColor

    SequentialAnimation {
        id: unlockAnimation

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 0
                duration: 450
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: root
                property: "scale"
                to: 1.06
                duration: 450
                easing.type: Easing.InOutCubic
            }
        }
        ScriptAction {
            script: root.unlocked()
        }
    }

    Services.SystemStatus {
        id: systemStatus
    }
    Services.NotificationBridge {
        id: notificationBridge
    }
    Services.MediaPlayer {
        id: mediaPlayer
    }

    Image {
        id: background
        anchors.fill: parent
        source: theme.wallpaper
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: background
        blurEnabled: true
        blur: 0.6
        blurMax: 48
        autoPaddingEnabled: false
    }

    Text {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 20
        text: "Whose eyes are those eyes?"
        font.pixelSize: 15
        font.family: root.fontFamily
        color: "#dddddd"
    }

    Components.NotificationStack {
        bridge: notificationBridge
        fontFamily: root.fontFamily
        accentColor: root.accentColor
    }
    Components.StatusBar {
        status: systemStatus
        fontFamily: root.fontFamily
    }
    Components.MediaPlayerCard {
        player: mediaPlayer
        fontFamily: root.fontFamily
    }

    Column {
        id: unlockPanel
        anchors.centerIn: parent
        spacing: 24

        Components.LockClock {
            id: clock

            property date now: new Date()

            anchors.horizontalCenter: parent.horizontalCenter
            fontFamily: root.fontFamily
            currentTime: Qt.formatTime(now, "hh:mm")
            currentDate: DateFormat.formatPt(now)
        }
        Components.PasswordPrompt {
            anchors.horizontalCenter: parent.horizontalCenter
            fontFamily: root.fontFamily
            accentColor: root.accentColor
            onAuthenticated: {
                root.enabled = false
                unlockAnimation.start()
            }
        }
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.now = new Date()
    }
    Components.PowerMenu {
        fontFamily: root.fontFamily
        accentColor: root.accentColor
    }
}
