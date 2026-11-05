// logic/FocusTimer.qml — Modo foco (pomodoro)
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "foco".
// Acesso de fora:  phone.foco.<membro>

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // ================================================================
  // FOCO
  // ================================================================

  property string pomoMode: "focus"          // focus | short | long

  property real pomoRemaining: 25 * 60       // segundos, quando parado

  property bool pomoRunning: false

  property real pomoEnd: 0                   // ms (Date.now) quando termina

  property real pomoNow: Date.now()

  property int pomoCycles: 0                 // sessões de foco concluídas

  readonly property var pomoLen: ({
    focus: 25 * 60,
    short: 5 * 60,
    long: 15 * 60
  })

  readonly property real pomoLeft:
    pomoRunning
      ? Math.max(0, (pomoEnd - pomoNow) / 1000)
      : pomoRemaining

  readonly property real pomoRatio:
    1 - pomoLeft / pomoLen[pomoMode]

  function fmtMinSec(sec) {
    const s2 = Math.ceil(sec);
    const m = Math.floor(s2 / 60);

    return phone.music.pad2(m) + ":" + phone.music.pad2(s2 % 60);
  }

  function pomoToggle() {
    if (pomoRunning) {
      pomoRemaining = pomoLeft;
      pomoRunning = false;
    } else {
      pomoNow = Date.now();
      pomoEnd = pomoNow + pomoRemaining * 1000;
      pomoRunning = true;
    }
  }

  function pomoReset() {
    pomoRunning = false;
    pomoRemaining = pomoLen[pomoMode];
  }

  function pomoSetMode(m) {
    pomoRunning = false;
    pomoMode = m;
    pomoRemaining = pomoLen[m];
  }

  function pomoStep(d) {
    const modes = ["focus", "short", "long"];
    const i = modes.indexOf(pomoMode);

    pomoSetMode(modes[(i + d + modes.length) % modes.length]);
  }

  function pomoFinish() {
    pomoRunning = false;

    let title = "";
    let body = "";
    let next = "focus";

    if (pomoMode === "focus") {
      pomoCycles += 1;
      next = pomoCycles % 4 === 0 ? "long" : "short";
      title = "Foco concluído";
      body = next === "long"
        ? "Quatro ciclos! Pausa longa de 15 min."
        : "Hora de uma pausa de 5 min.";
    } else {
      title = "Pausa terminou";
      body = "Bora voltar pro foco.";
    }

    pomoMode = next;
    pomoRemaining = pomoLen[next];

    Quickshell.execDetached(["sh", "-c", `
      notify-send -a Celular "$1" "$2"
      paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null
    `, "sh", title, body]);
  }

  function handleFocoKey(e) {
    switch (e.key) {
    case Qt.Key_Escape:
      phone.view = "menu";
      break;

    case Qt.Key_Space:
    case Qt.Key_Return:
    case Qt.Key_Enter:
      pomoToggle();
      break;

    case Qt.Key_R:     pomoReset();            break;
    case Qt.Key_1:     pomoSetMode("focus");   break;
    case Qt.Key_2:     pomoSetMode("short");   break;
    case Qt.Key_3:     pomoSetMode("long");    break;
    case Qt.Key_Left:  pomoStep(-1);           break;
    case Qt.Key_Right: pomoStep(1);            break;

    default:
      return;
    }

    e.accepted = true;
  }

  Timer {
    interval: 250
    repeat: true
    running: phone.foco.pomoRunning

    onTriggered: {
      phone.foco.pomoNow = Date.now();

      if (phone.foco.pomoLeft <= 0)
        phone.foco.pomoFinish();
    }
  }
}
