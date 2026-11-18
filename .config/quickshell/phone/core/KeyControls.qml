// core/KeyControls.qml — Softkeys, D-pad e botões físicos
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "controls".
// Acesso de fora:  phone.controls.<membro>

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // ---------------- softkeys ----------------

  readonly property var activeLogic: {
    const app = phone.registry.activeApp();
    return app ? app.logic : null;
  }

  readonly property string softLeftText:
    activeLogic && activeLogic.softLeftText !== undefined ? activeLogic.softLeftText : ""

  readonly property string softCenterText:
    activeLogic && activeLogic.softCenterText !== undefined ? activeLogic.softCenterText : ""

  readonly property string softRightText:
    activeLogic && activeLogic.softRightText !== undefined ? activeLogic.softRightText : "Voltar"

  function softLeft() {
    if (activeLogic && typeof activeLogic.softLeft === "function")
      activeLogic.softLeft();
  }

  function softCenter() {
    if (activeLogic && typeof activeLogic.softCenter === "function")
      activeLogic.softCenter();
  }

  function softRight() {
    if (activeLogic && typeof activeLogic.softRight === "function")
      activeLogic.softRight();
  }

  // ---------------- botões de metal ----------------
  // 0 ✉ Discord | 1 ⓘ info | 2 📖 PDFCraft | 3 📷 print

  // procura um app do menu pelo nome/id; se não achar, roda o comando
  function launchByName(pattern, fallbackCmd) {
    const re = new RegExp(pattern, "i");

    for (let i = 0; i < phone.menu.allEntries.length; i++) {
      const e = phone.menu.allEntries[i];

      if (re.test(e.name) || re.test(e.id || "")) {
        e.execute();
        return;
      }
    }

    if (fallbackCmd)
      Quickshell.execDetached(fallbackCmd);
  }

  function metal(i) {
    if (i === 0) {
      launchByName("discord", ["discord"]);
      phone.panelOpen = false;
    } else if (i === 1) {
      phone.view = "info";
    } else if (i === 2) {
      Quickshell.execDetached([phone.pdfApp]);
      phone.panelOpen = false;
    } else {
      // some primeiro, senão o próprio celular sai no print
      phone.panelOpen = false;
      shotTimer.restart();
    }
  }

  // ---------------- D-pad, softkeys, ligar/desligar ----------------

  // setas: no menu/arquivos/etc. viram teclas; no player controlam música
  function dpad(key) {
    const app = phone.registry.activeApp();
    if (app && !app.capturesKeys)
      return;

    phone.keyDispatcher.handleKey({ key: key, text: "", modifiers: 0, accepted: false });
  }

  // sl/sr = softkeys (traços) | call/ok = Selecionar | end = home / fechar
  function pad(k) {
    switch (k) {
    case "sl":   softLeft();   break;
    case "sr":   softRight();  break;
    case "ok":
    case "call": softCenter(); break;

    case "end":
      if (phone.view !== "menu")
        phone.view = "menu";
      else
        phone.panelOpen = false;
      break;

    case "up":    dpad(Qt.Key_Up);    break;
    case "down":  dpad(Qt.Key_Down);  break;
    case "left":  dpad(Qt.Key_Left);  break;
    case "right": dpad(Qt.Key_Right); break;
    }
  }

  Timer {
    id: shotTimer

    interval: 500
    repeat: false

    onTriggered:
      Quickshell.execDetached(["sh", "-c", "grim - | wl-copy"])
  }
}
