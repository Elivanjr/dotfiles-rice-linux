// logic/KeyControls.qml — Teclado global, softkeys, D-pad, botões de metal e do teclado numérico
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "controls".
// Acesso de fora:  phone.controls.<membro>

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  function handleKey(e) {
    if (phone.view === "news") {
      phone.news.handleNewsKey(e);
      return;
    }

    if (phone.view === "snake") {
      phone.snake.handleSnakeKey(e);
      return;
    }

    if (phone.view === "calc") {
      phone.calc.handleCalcKey(e);
      return;
    }

    if (phone.view === "term") {
      phone.term.handleTermKey(e);
      return;
    }

    if (phone.view === "sched") {
      phone.sched.handleSchedKey(e);
      return;
    }

    if (phone.view === "dl") {
      phone.dl.handleDlKey(e);
      return;
    }

    if (phone.view === "clip") {
      phone.clip.handleClipKey(e);
      return;
    }

    if (phone.view === "music") {
      phone.music.handleMusicKey(e);
      return;
    }

    if (phone.view === "settings") {
      phone.config.handleSettingsKey(e);
      return;
    }

    if (phone.view === "ai") {
      phone.ai.handleAiKey(e);
      return;
    }

    if (phone.view === "ssh") {
      phone.ssh.handleSshKey(e);
      return;
    }

    if (phone.view === "wall") {
      phone.walls.handleWallKey(e);
      return;
    }

    if (phone.view === "files") {
      phone.files.handleFilesKey(e);
      return;
    }

    if (phone.view === "foco") {
      phone.foco.handleFocoKey(e);
      return;
    }

    if (phone.view === "share") {
      phone.share.handleShareKey(e);
      return;
    }

    if (phone.view !== "menu")
      return;

    if (phone.menu.optionsOpen) {
      phone.menu.handleOptKey(e);
      return;
    }

    switch (e.key) {
    case Qt.Key_Escape:
      if (phone.menu.optionsOpen)
        phone.menu.optionsOpen = false;
      else if (phone.menu.query !== "")
        phone.menu.query = "";
      else
        phone.panelOpen = false;
      break;

    case Qt.Key_Left:  phone.menu.move(-1); break;
    case Qt.Key_Right: phone.menu.move(1);  break;
    case Qt.Key_Up:    phone.menu.move(-4); break;
    case Qt.Key_Down:  phone.menu.move(4);  break;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      phone.menu.launchSelected();
      break;

    case Qt.Key_Backspace:
      phone.menu.query = phone.menu.query.slice(0, -1);
      break;

    default:
      if (e.text && e.text.length === 1 && e.text >= " ")
        phone.menu.query += e.text;
      else
        return;
    }

    e.accepted = true;
  }

  // ---------------- softkeys ----------------

  readonly property string softLeftText:
    phone.view === "calc"
      ? "Apagar"
    : phone.view === "snake"
      ? "Reiniciar"
    : phone.view === "term"
      ? "Limpar"
    : phone.view === "sched"
      ? phone.sched.schedSoftLeft
    : phone.view === "dl"
      ? phone.dl.dlSoftLeft
    : phone.view === "news"
      ? phone.news.newsSoftLeft
    : phone.view === "clip"
      ? phone.clip.clipSoftLeft
    : phone.view === "settings"
      ? phone.config.setSoftLeft
    : phone.view === "ai"
      ? "Opções"
    : phone.view === "ssh"
      ? phone.ssh.sshSoftLeft
    : phone.view === "menu"
      ? "Opções"
      : phone.view === "share"
        ? "Atualizar"
        : phone.view === "foco"
          ? "Zerar"
        : phone.view === "files"
          ? (phone.files.showHidden ? "Ocultar" : "Ocultos")
        : (phone.view === "info" || phone.view === "wall")
          ? "Atualizar"
        : (phone.music.playerList && phone.music.playerList.length > 1 ? "Player" : "")

  readonly property string softCenterText:
    phone.view === "calc"
      ? "OK"
    : phone.view === "snake"
      ? phone.snake.snakeSoftCenter
    : phone.view === "term"
      ? (phone.term.termBusy > 0 ? "Parar" : "Enviar")
    : phone.view === "sched"
      ? phone.sched.schedSoftCenter
    : phone.view === "dl"
      ? phone.dl.dlSoftCenter
    : phone.view === "news"
      ? phone.news.newsSoftCenter
    : phone.view === "clip"
      ? phone.clip.clipSoftCenter
    : phone.view === "settings"
      ? phone.config.setSoftCenter
    : phone.view === "ai"
      ? (phone.ai.aiBusy ? "Parar" : "Enviar")
    : phone.view === "ssh"
      ? phone.ssh.sshSoftCenter
    : phone.view === "menu"
      ? "Selecionar"
      : phone.view === "share"
        ? ((phone.share.shareStep === "done" || !phone.share.shareHasExt) ? "" : "Escolher")
        : phone.view === "foco"
          ? (phone.foco.pomoRunning ? "Pausar" : "Iniciar")
        : phone.view === "files"
          ? (phone.files.filesPick ? "Escolher" : "Abrir")
        : phone.view === "wall"
          ? "Aplicar"
          : phone.view === "info"
            ? "Trocar foto"
            : (phone.music.hasPlayer && phone.music.player.isPlaying ? "Pausar" : "Tocar")

  readonly property string softRightText:
    phone.view === "settings" ? phone.config.setSoftRight
      : phone.view === "ssh" ? phone.ssh.sshSoftRight
      : phone.view === "sched" ? phone.sched.schedSoftRight
      : phone.view === "dl" ? phone.dl.dlSoftRight
      : phone.view === "news" ? phone.news.newsSoftRight
      : phone.view === "clip" ? phone.clip.clipSoftRight
      : "Voltar"

  function softLeft() {
    if (phone.view === "calc")
      phone.calc.calcPress("BS");
    else if (phone.view === "snake")
      phone.snake.reiniciar();
    else if (phone.view === "term")
      phone.term.termModel.clear();
    else if (phone.view === "sched")
      phone.sched.schedLeftKey();
    else if (phone.view === "dl")
      phone.dl.dlLeftKey();
    else if (phone.view === "news")
      phone.news.newsLeftKey();
    else if (phone.view === "clip")
      phone.clip.clipLeftKey();
    else if (phone.view === "settings")
      phone.config.setLeftKey();
    else if (phone.view === "ai")
      phone.ai.aiLeftKey();
    else if (phone.view === "ssh")
      phone.ssh.sshLeftKey();
    else if (phone.view === "menu")
      phone.menu.optionsOpen = !phone.menu.optionsOpen;
    else if (phone.view === "info")
      phone.info.refreshInfo();
    else if (phone.view === "wall")
      phone.walls.refreshWalls();
    else if (phone.view === "files")
      phone.files.showHidden = !phone.files.showHidden;
    else if (phone.view === "foco")
      phone.foco.pomoReset();
    else if (phone.view === "share")
      phone.share.refreshShare();
    else
      phone.music.cyclePlayer();
  }

  function softCenter() {
    if (phone.view === "calc")
      phone.calc.calcPress(phone.calc.calcKeys[phone.calc.calcSel].k);
    else if (phone.view === "snake")
      phone.snake.alternar();
    else if (phone.view === "term")
      phone.term.termCenterKey();
    else if (phone.view === "sched")
      phone.sched.schedCenterKey();
    else if (phone.view === "dl")
      phone.dl.dlCenterKey();
    else if (phone.view === "news")
      phone.news.newsCenterKey();
    else if (phone.view === "clip")
      phone.clip.clipCenterKey();
    else if (phone.view === "settings")
      phone.config.setCenterKey();
    else if (phone.view === "ai")
      phone.ai.aiCenterKey();
    else if (phone.view === "ssh")
      phone.ssh.sshCenterKey();
    else if (phone.view === "menu" && phone.menu.optionsOpen)
      phone.menu.optRun(phone.menu.optSel);
    else if (phone.view === "menu")
      phone.menu.launchSelected();
    else if (phone.view === "music")
      phone.music.press(1);
    else if (phone.view === "wall")
      phone.walls.applyWall(phone.walls.wallpapers[phone.walls.wallSelected]);
    else if (phone.view === "files")
      phone.files.openSelectedFile();
    else if (phone.view === "info")
      phone.files.openFiles(true);
    else if (phone.view === "foco")
      phone.foco.pomoToggle();
    else if (phone.view === "share")
      phone.share.shareChoose();
  }

  function softRight() {
    if (phone.view === "calc" || phone.view === "term" || phone.view === "snake") {
      phone.view = "menu";
      return;
    }

    if (phone.view === "sched") {
      phone.sched.schedBack();
      return;
    }

    if (phone.view === "dl") {
      phone.dl.dlBack();
      return;
    }

    if (phone.view === "clip") {
      phone.clip.clipBack();
      return;
    }

    if (phone.view === "news") {
      phone.news.newsBack();
      return;
    }

    if (phone.view === "settings") {
      phone.config.setBack();
      return;
    }

    if (phone.view === "ai") {
      phone.ai.aiBack();
      return;
    }

    if (phone.view === "ssh") {
      phone.ssh.sshBack();
      return;
    }

    if (phone.view === "share") {
      phone.share.shareBack();
      return;
    }

    if (phone.view === "files") {
      // sobe de pasta até a home; da home volta pro menu
      if (phone.files.filesDir !== phone.files.homeDir && phone.files.filesDir !== "/")
        phone.files.goUp();
      else
        phone.view = phone.files.filesReturnView;

      return;
    }

    if (phone.view === "music" || phone.view === "info" || phone.view === "wall" || phone.view === "foco") {
      phone.view = "menu";
      return;
    }

    if (phone.menu.optionsOpen)
      phone.menu.optionsOpen = false;
    else if (phone.menu.query !== "")
      phone.menu.query = "";
    else
      phone.panelOpen = false;
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
    if (phone.view === "music") {
      if (key === Qt.Key_Up)         phone.music.changeVolume(0.05);
      else if (key === Qt.Key_Down)  phone.music.changeVolume(-0.05);
      else if (key === Qt.Key_Left)  phone.music.press(0);
      else if (key === Qt.Key_Right) phone.music.press(2);

      return;
    }

    if (phone.view === "info")
      return;

    handleKey({ key: key, text: "", modifiers: 0, accepted: false });
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
