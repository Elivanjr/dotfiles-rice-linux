import QtQuick
import Quickshell.Services.Mpris

Item {
    id: service
    visible: false
    property var activePlayer: null
    property int tick: 0
    property string trackTitle: { service.tick; return service.activePlayer ? (service.activePlayer.trackTitle || "Sem título") : "Nada tocando" }
    property string trackArtist: service.activePlayer ? (service.activePlayer.trackArtist || "") : ""
    property string trackArtUrl: service.activePlayer ? service.activePlayer.trackArtUrl : ""
    property real trackPositionSec: { service.tick; return service.activePlayer ? service.activePlayer.position : 0 }
    property real trackLengthSec: service.activePlayer ? service.activePlayer.length : 0
    property bool trackPlaying: service.activePlayer ? service.activePlayer.isPlaying : false

    Timer { interval: 1500; running: true; repeat: true; triggeredOnStart: true; onTriggered: service.activePlayer = service.pickActivePlayer() }
    Timer { interval: 1000; running: service.activePlayer !== null && service.activePlayer.isPlaying; repeat: true; onTriggered: service.tick++ }

    function pickActivePlayer() {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) if (players[i].dbusName.toLowerCase().indexOf("spotify") !== -1) return players[i]
        for (var j = 0; j < players.length; j++) if (players[j].dbusName.toLowerCase().indexOf("mpv") !== -1) return players[j]
        for (var k = 0; k < players.length; k++) if (players[k].isPlaying) return players[k]
        return players.length > 0 ? players[0] : null
    }
    function formatTime(seconds) {
        var minutes = Math.floor(seconds / 60)
        var remainder = Math.floor(seconds % 60)
        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder
    }
}
