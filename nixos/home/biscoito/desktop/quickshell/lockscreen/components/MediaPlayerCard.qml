import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Rectangle {
    id: card
    property var player
    property string fontFamily: "sans-serif"
    visible: player && player.activePlayer !== null
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.margins: 20
    width: 420
    height: content.implicitHeight + 32
    radius: 16
    color: "#cc17171b"
    border.color: "#22ffffff"
    border.width: 1

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            ClippingRectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 100
                radius: 12
                color: "#333333"
                Image { anchors.fill: parent; source: card.player ? card.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            }
            ColumnLayout {
                Layout.fillWidth: true
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "TOCANDO AGORA"; font.pixelSize: 9; font.family: card.fontFamily; color: "#8bc34a" }
                    Item { Layout.fillWidth: true }
                    Text { text: card.player ? card.player.formatTime(card.player.trackPositionSec) + " / " + card.player.formatTime(card.player.trackLengthSec) : ""; font.pixelSize: 11; font.family: card.fontFamily; color: "#999999" }
                }
                Text { text: card.player ? card.player.trackTitle : ""; font.pixelSize: 12; font.family: card.fontFamily; font.bold: true; color: "#aed581"; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: card.player ? card.player.trackArtist : ""; font.pixelSize: 10; font.family: card.fontFamily; color: "#aaaaaa" }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 22
            MediaButton { icon: "\uf048"; onClicked: if (card.player.activePlayer && card.player.activePlayer.canGoPrevious) card.player.activePlayer.previous() }
            MediaButton { icon: card.player && card.player.trackPlaying ? "\uf04c" : "\uf04b"; primary: true; onClicked: if (card.player.activePlayer && card.player.activePlayer.canTogglePlaying) card.player.activePlayer.togglePlaying() }
            MediaButton { icon: "\uf051"; onClicked: if (card.player.activePlayer && card.player.activePlayer.canGoNext) card.player.activePlayer.next() }
        }
        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: "#33ffffff"
            Rectangle { height: parent.height; radius: 2; color: "#aed581"; width: parent.width * (card.player && card.player.trackLengthSec > 0 ? card.player.trackPositionSec / card.player.trackLengthSec : 0) }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: card.player ? card.player.formatTime(card.player.trackPositionSec) : "0:00"; font.pixelSize: 11; font.family: card.fontFamily; color: "#999999" }
            Item { Layout.fillWidth: true }
            Text { text: card.player ? card.player.formatTime(card.player.trackLengthSec) : "0:00"; font.pixelSize: 11; font.family: card.fontFamily; color: "#999999" }
        }
    }

    component MediaButton: Rectangle {
        property string icon
        property bool primary: false
        signal clicked()
        width: primary ? 40 : 32
        height: width
        radius: width / 2
        color: primary ? "#aed581" : "#2e3d22"
        Text { anchors.centerIn: parent; text: parent.icon; font.pixelSize: 13; font.family: card.fontFamily; color: parent.primary ? "#101014" : "#aed581" }
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }
}
