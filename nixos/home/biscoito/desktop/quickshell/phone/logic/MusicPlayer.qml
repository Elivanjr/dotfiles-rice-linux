// logic/MusicPlayer.qml — Player MPRIS e relógio
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "music".
// Acesso de fora:  phone.music.<membro>

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Scope {
  id: self

  required property var phone

  // ================================================================
  // MPRIS
  // ================================================================

  property var manualPlayer: null

  property var now: new Date()

  // Navegadores aparecem duas vezes no MPRIS (o próprio navegador e o
  // plasma-browser-integration). Quando dois players têm o mesmo título,
  // fica só o que tem mais metadados (capa > artista > álbum).
  function normTitle(t) {
    return (t || "")
      .toLowerCase()
      .replace(/\s*[-–|]\s*youtube\s*$/, "")
      .trim();
  }

  function metaScore(p) {
    return (p.trackArtUrl ? 4 : 0)
      + (p.trackArtist ? 2 : 0)
      + (p.trackAlbum ? 1 : 0)
      + (p.isPlaying ? 0.5 : 0);
  }

  readonly property var playerList: {
    const all = Mpris.players.values;
    const out = [];

    for (let i = 0; i < all.length; i++) {
      const na = normTitle(all[i].trackTitle);
      let dup = false;

      for (let j = 0; j < all.length && !dup; j++) {
        if (i === j)
          continue;

        if (na === "" || na !== normTitle(all[j].trackTitle))
          continue;

        const sa = metaScore(all[i]);
        const sb = metaScore(all[j]);

        // perde quem tem menos metadados; empate: fica o primeiro da lista
        if (sb > sa || (sb === sa && j < i))
          dup = true;
      }

      if (!dup)
        out.push(all[i]);
    }

    return out;
  }

  readonly property var player: {
    const list = playerList;

    if (!list || list.length === 0)
      return null;

    if (manualPlayer && list.indexOf(manualPlayer) >= 0)
      return manualPlayer;

    for (let i = 0; i < list.length; i++) {
      if (list[i].isPlaying)
        return list[i];
    }

    return list[0];
  }

  readonly property bool hasPlayer: player !== null

  readonly property string trackTitle:
    hasPlayer ? (player.trackTitle || "Sem título") : ""

  readonly property string trackArtist:
    hasPlayer ? (player.trackArtist || "Desconhecido") : ""

  readonly property real progress: {
    if (!hasPlayer || !player.lengthSupported || player.length <= 0)
      return 0;

    return Math.max(0, Math.min(1, player.position / player.length));
  }

  readonly property real volumeRatio:
    hasPlayer && player.volumeSupported ? player.volume : 0

  function pad2(n) {
    return (n < 10 ? "0" : "") + n;
  }

  function fmt(sec) {
    if (!sec || isNaN(sec) || sec < 0)
      return "0:00";

    const m = Math.floor(sec / 60);
    const ss = Math.floor(sec % 60);

    return m + ":" + pad2(ss);
  }

  function clockText() {
    return pad2(now.getHours()) + ":" + pad2(now.getMinutes());
  }

  function changeVolume(delta) {
    if (!hasPlayer || !player.volumeSupported || !player.canControl)
      return;

    player.volume = Math.max(0, Math.min(1, player.volume + delta));
  }

  function setVolume(ratio) {
    if (!hasPlayer || !player.volumeSupported || !player.canControl)
      return;

    player.volume = Math.max(0, Math.min(1, ratio));
  }

  function cyclePlayer() {
    const list = playerList;

    if (!list || list.length < 2)
      return;

    const i = list.indexOf(player);
    manualPlayer = list[(i + 1) % list.length];
  }

  function seekTo(ratio) {
    if (!hasPlayer || !player.canSeek || !player.lengthSupported)
      return;

    player.position = Math.max(0, Math.min(1, ratio)) * player.length;
  }

  // 0 anterior | 1 play/pause | 2 próxima
  function press(i) {
    if (!hasPlayer)
      return;

    if (i === 0 && player.canGoPrevious)
      player.previous();
    else if (i === 1 && player.canTogglePlaying)
      player.togglePlaying();
    else if (i === 2 && player.canGoNext)
      player.next();
  }

  // Teclado na tela do player (mesmo padrão dos outros apps):
  // Esc volta ao menu | Enter/Espaço play-pause | ←/→ faixa | ↑/↓ volume
  function handleMusicKey(e) {
    switch (e.key) {
    case Qt.Key_Escape:
      phone.view = "menu";
      break;

    case Qt.Key_Space:
    case Qt.Key_Return:
    case Qt.Key_Enter:
      press(1);
      break;

    case Qt.Key_Left:  press(0);           break;
    case Qt.Key_Right: press(2);           break;
    case Qt.Key_Up:    changeVolume(0.05); break;
    case Qt.Key_Down:  changeVolume(-0.05); break;

    default:
      return;
    }

    e.accepted = true;
  }

  Timer {
    interval: 1000
    running: phone.panelOpen
    repeat: true
    triggeredOnStart: true

    onTriggered: {
      phone.music.now = new Date();

      if (phone.music.hasPlayer && phone.music.player.isPlaying)
        phone.music.player.positionChanged();
    }
  }
}
