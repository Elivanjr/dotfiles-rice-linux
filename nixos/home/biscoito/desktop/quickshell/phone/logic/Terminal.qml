// logic/Terminal.qml — Terminal local do celular (bash persistente)
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "term".
// Acesso de fora:  phone.term.<membro>
//
// Como funciona: um bash fica vivo em segundo plano (sem TTY). Cada comando é
// escrito no stdin e, depois dele, o bash imprime um marcador com o código de
// saída e o diretório atual (é assim que o prompt sabe onde você está).
//
// Limites: sem TTY, então vim, htop, sudo e ssh com senha não funcionam.
// Ctrl+C interrompe o comando; se o bash travar, reinicia o shell.

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // lista da view (a própria view se registra por Binding)
  property var termListRef: null

  // linhas do terminal: { kind: cmd | out | err | sys, txt }
  property alias termModel: termModelObj

  property string termInput: ""

  property var termHist: []

  property int termHistPos: -1

  // comandos enviados que ainda não terminaram
  property int termBusy: 0

  // o bash já respondeu o primeiro marcador
  property bool termUp: false

  // acompanha o fim da lista enquanto chega saída
  property bool termStick: true

  property int termPid: 0

  property bool termRestarting: false

  // comandos digitados antes do shell ficar pronto
  property var termQueue: []

  property string termCwd: phone.files.homeDir

  readonly property string termCwdShort: {
    const h = phone.files.homeDir;

    if (termCwd === h)
      return "~";

    if (h !== "" && termCwd.indexOf(h + "/") === 0)
      return "~" + termCwd.slice(h.length);

    return termCwd;
  }

  // sem TTY: desliga paginadores e cores
  readonly property var termEnv: ({
    TERM: "dumb",
    PAGER: "cat",
    GIT_PAGER: "cat",
    SYSTEMD_PAGER: ""
  })

  ListModel {
    id: termModelObj
  }

  // ---------------- shell ----------------

  Process {
    id: termProc

    // o bash inicial imprime o PID e o diretório, depois vira o shell de verdade
    command: [
      "bash", "-c",
      "printf '__QTERMPID__%s\\n__QTERM__0:%s\\n' \"$$\" \"$PWD\"; exec bash --noprofile --norc"
    ]
    stdinEnabled: true
    environment: self.termEnv
    workingDirectory: self.termCwd

    stdout: SplitParser {
      onRead: (data) => self.termOnLine(data)
    }

    stderr: SplitParser {
      onRead: (data) => self.termOnErr(data)
    }

    onExited: (code, status) => self.termOnExit(code)
  }

  // se o Ctrl+C não destravar o shell, reinicia
  Timer {
    id: termIntTimer

    interval: 700
    repeat: false

    onTriggered: {
      if (self.termBusy > 0)
        self.termRestart();
    }
  }

  // Ctrl+V: cola o clipboard na linha de comando
  Process {
    id: termPasteProc

    command: ["wl-paste", "-n", "-t", "text"]

    stdout: StdioCollector {
      onStreamFinished: self.termType(this.text)
    }
  }

  // chamado pelo shell.qml quando a tela do terminal abre
  function termEnter() {
    termStick = true;
    termStart();
  }

  function termStart() {
    if (termProc.running)
      return;

    termUp = false;
    termPid = 0;
    termProc.running = true;
  }

  function termClean(s) {
    return String(s).replace(/\r/g, "").replace(/\x1b\[[0-9;?]*[ -\/]*[@-~]/g, "");
  }

  function termPush(kind, txt) {
    if (termModel.count > 500)
      termModel.remove(0, 120);

    termModel.append({ kind: kind, txt: txt });
  }

  function termOnErr(raw) {
    const l = termClean(raw);

    if (l.trim() === "")
      return;

    termPush("err", l);
  }

  function termOnLine(raw) {
    const line = termClean(raw);
    const pi = line.indexOf("__QTERMPID__");

    if (pi >= 0) {
      termPid = parseInt(line.slice(pi + 12)) || 0;
      return;
    }

    const i = line.indexOf("__QTERM__");

    if (i < 0) {
      termPush("out", line);
      return;
    }

    const pre = line.slice(0, i);

    if (pre !== "")
      termPush("out", pre);

    const rest = line.slice(i + 9);
    const c = rest.indexOf(":");

    if (c < 0)
      return;

    termOnDone(parseInt(rest.slice(0, c)), rest.slice(c + 1));
  }

  function termOnDone(code, pwd) {
    const first = !termUp;

    termBusy = Math.max(0, termBusy - (first ? 0 : 1));
    termCwd = pwd;

    if (first) {
      termUp = true;

      if (termModel.count === 0)
        termPush("sys", "bash · sem TTY (vim, htop e sudo não rodam) · Ctrl+C interrompe");

      const q = termQueue;

      termQueue = [];

      for (let i = 0; i < q.length; i++)
        termWrite(q[i]);
    } else if (code === 130) {
      termPush("sys", "^C");
    } else if (code !== 0) {
      termPush("sys", "exit " + code);
    }
  }

  function termOnExit(code) {
    termUp = false;
    termPid = 0;
    termBusy = 0;

    if (termRestarting) {
      termRestarting = false;
      termStart();
      return;
    }

    termPush("sys", "shell encerrado (código " + code + ") · o próximo comando reinicia");
  }

  // ---------------- enviar comandos ----------------

  // o { } com </dev/null evita que um comando (ex.: cat) engula os próximos
  function termWrite(cmd) {
    termProc.write("{ " + cmd + "\n} </dev/null\nprintf '__QTERM__%s:%s\\n' \"$?\" \"$PWD\"\n");
  }

  function termRun(cmd) {
    termPush("cmd", termCwdShort + " $ " + cmd);
    termBusy++;
    termStick = true;

    if (termProc.running && termUp) {
      termWrite(cmd);
      return;
    }

    termQueue = termQueue.concat([cmd]);
    termStart();
  }

  function termSubmit() {
    const c = termInput;
    const t = c.trim();

    termInput = "";
    termHistPos = -1;

    if (t === "") {
      termPush("cmd", termCwdShort + " $");
      return;
    }

    if (termHist.length === 0 || termHist[termHist.length - 1] !== c)
      termHist = termHist.concat([c]).slice(-100);

    if (t === "clear" || t === "cls") {
      termModel.clear();
      return;
    }

    if (t === "exit" || t === "logout") {
      phone.view = "menu";
      return;
    }

    termRun(c);
  }

  // texto digitado ou colado
  function termType(str) {
    if (!str)
      return;

    termInput += String(str).replace(/\r?\n+$/, "").replace(/\r?\n/g, " ");
  }

  // ---------------- interromper / reiniciar ----------------

  function termInterrupt() {
    if (termBusy > 0 && termPid > 0) {
      Quickshell.execDetached(["pkill", "-INT", "-P", String(termPid)]);
      termIntTimer.restart();
      return;
    }

    termPush("sys", "^C");
    termInput = "";
    termHistPos = -1;
  }

  function termRestart() {
    termIntTimer.stop();
    termQueue = [];

    if (termPid > 0)
      Quickshell.execDetached(["pkill", "-TERM", "-P", String(termPid)]);

    termPush("sys", "shell reiniciado");

    if (termProc.running) {
      termRestarting = true;
      termProc.running = false;
    } else {
      termBusy = 0;
      termStart();
    }
  }

  // ---------------- teclado e softkeys ----------------

  // softkey do meio: envia, ou interrompe se estiver ocupado
  function termCenterKey() {
    if (termBusy > 0)
      termInterrupt();
    else
      termSubmit();
  }

  function termScroll(dir) {
    const l = termListRef;

    if (!l)
      return;

    if (dir < 0) {
      termStick = false;
      l.contentY = Math.max(0, l.contentY - l.height * 0.8);
    } else {
      l.contentY = Math.max(0, Math.min(l.contentHeight - l.height, l.contentY + l.height * 0.8));
      termStick = l.atYEnd;
    }
  }

  function handleTermKey(e) {
    const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
    const shift = (e.modifiers & Qt.ShiftModifier) !== 0;
    let ok = true;

    if (ctrl) {
      switch (e.key) {
      case Qt.Key_C:
        termInterrupt();
        break;

      case Qt.Key_L:
        termModel.clear();
        break;

      case Qt.Key_U:
        termInput = "";
        break;

      case Qt.Key_V:
        if (!termPasteProc.running)
          termPasteProc.running = true;

        break;

      default:
        ok = false;
      }
    } else {
      switch (e.key) {
      case Qt.Key_Escape:
        phone.view = "menu";
        break;

      case Qt.Key_Return:
      case Qt.Key_Enter:
        termSubmit();
        break;

      case Qt.Key_Backspace:
        termInput = termInput.slice(0, -1);
        break;

      case Qt.Key_Insert:
        if (shift && !termPasteProc.running)
          termPasteProc.running = true;
        else
          ok = false;

        break;

      case Qt.Key_Up:
        if (termHist.length > 0) {
          termHistPos = termHistPos < 0 ? termHist.length - 1 : Math.max(0, termHistPos - 1);
          termInput = termHist[termHistPos];
        }

        break;

      case Qt.Key_Down:
        if (termHistPos >= 0) {
          termHistPos++;

          if (termHistPos >= termHist.length) {
            termHistPos = -1;
            termInput = "";
          } else {
            termInput = termHist[termHistPos];
          }
        }

        break;

      case Qt.Key_PageUp:
        termScroll(-1);
        break;

      case Qt.Key_PageDown:
        termScroll(1);
        break;

      default:
        if (e.text && e.text.length === 1 && e.text >= " ")
          termInput += e.text;
        else
          ok = false;
      }
    }

    if (ok)
      e.accepted = true;
  }
}
