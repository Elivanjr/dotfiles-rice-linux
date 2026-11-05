// logic/Downloader.qml — Baixar vídeos e áudio com o yt-dlp
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "dl".
// Acesso de fora:  phone.dl.<membro>
// Tela: views/DownloadView.qml | Script: scripts/ytdlp/ytdlp-helper.py
//
// Fluxo: url -> loading -> pick -> down -> done
//   url      cola/digita o link
//   loading  `ytdlp-helper.py info`  (título, canal, duração, formatos)
//   pick     escolhe a resolução (ou "Só áudio")
//   down     `ytdlp-helper.py baixar` com barra de progresso
//   done     caminho do arquivo + abrir pasta
//
// O script fala por linhas com prefixo (INFO / PROGRESS / STATUS / DONE / ERROR);
// o resultado vem sempre por essas linhas, nunca só pelo código de saída.

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  property string dlStage: "url"            // url | loading | pick | down | done

  property string dlUrl: ""

  property string dlMsg: ""                 // erro/aviso (tela do link e da lista)

  property string dlTitle: ""

  property string dlChannel: ""

  property string dlDuration: ""

  property var dlOptions: []                // [{ id, rotulo, temAudio }]

  property int dlSel: 0

  // download em andamento
  property real dlPct: 0

  property int dlSpeed: 0                   // bytes/s

  property int dlEta: -1

  property int dlStep: 1

  property int dlSteps: 1

  property string dlStatus: ""

  property string dlFile: ""

  // controle interno
  property bool dlTerminal: false           // já chegou DONE/ERROR/INFO desta execução

  property bool dlCancelled: false

  property string dlLastErr: ""             // última linha do stderr (para falha sem ERROR)

  readonly property string dlScript:
    decodeURIComponent(String(Qt.resolvedUrl("../scripts/ytdlp/ytdlp-helper.py")).replace("file://", ""))

  // ---------------- texto ----------------

  readonly property string dlTitleBar: {
    switch (dlStage) {
    case "loading": return "Buscando";
    case "pick":    return "Qualidade";
    case "down":    return "Baixando";
    case "done":    return "Pronto";
    default:        return "Baixar";
    }
  }

  readonly property string dlSubtitle: {
    switch (dlStage) {
    case "url":     return "Vídeo ou áudio com yt-dlp";
    case "loading": return "Lendo as informações do link…";
    case "pick":    return dlChannel !== "" ? dlChannel + (dlDuration !== "" ? " · " + dlDuration : "") : dlDuration;
    case "down":    return dlSteps > 1 ? ("Etapa " + dlStep + " de " + dlSteps) : "Em andamento";
    default:        return "Arquivo salvo";
    }
  }

  readonly property string dlSoftLeft:
    dlStage === "url" ? "Colar" : (dlStage === "done" ? "Novo" : "")

  readonly property string dlSoftCenter: {
    switch (dlStage) {
    case "url":  return dlUrl.trim() === "" ? "" : "Buscar";
    case "pick": return "Baixar";
    case "done": return "Pasta";
    default:     return "";
    }
  }

  readonly property string dlSoftRight:
    (dlStage === "loading" || dlStage === "down") ? "Cancelar" : "Voltar"

  function fmtSpeed(bps) {
    if (!bps || bps <= 0)
      return "";

    if (bps >= 1048576)
      return (bps / 1048576).toFixed(1) + " MB/s";

    return Math.round(bps / 1024) + " KB/s";
  }

  function fmtEta(sec) {
    if (sec < 0)
      return "";

    const m = Math.floor(sec / 60);
    const s = sec % 60;

    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
  }

  readonly property string dlDetail: {
    const p = Math.round(dlPct) + "%";
    const sp = fmtSpeed(dlSpeed);
    const eta = fmtEta(dlEta);

    return p + (sp !== "" ? " · " + sp : "") + (eta !== "" ? " · faltam " + eta : "");
  }

  readonly property string dlFolder: {
    const i = dlFile.lastIndexOf("/");

    return i > 0 ? dlFile.slice(0, i) : "";
  }

  // ---------------- link ----------------

  function dlSetUrl(v) {
    dlUrl = v;
    dlMsg = "";
  }

  function dlType(str) {
    if (!str)
      return;

    const t = String(str).replace(/\s+/g, "");

    dlSetUrl((dlUrl + t).slice(0, 600));
  }

  function dlNew() {
    dlStage = "url";
    dlUrl = "";
    dlMsg = "";
    dlFile = "";
    dlOptions = [];
  }

  // ---------------- info ----------------

  function dlFetch() {
    const u = dlUrl.trim();

    if (u === "") {
      dlMsg = "Cole ou digite o link do vídeo.";
      return;
    }

    if (!/^https?:\/\//i.test(u)) {
      dlMsg = "O link precisa começar com http:// ou https://";
      return;
    }

    if (dlInfoProc.running)
      return;

    dlUrl = u;
    dlMsg = "";
    dlLastErr = "";
    dlTerminal = false;
    dlCancelled = false;
    dlStage = "loading";
    dlInfoProc.command = ["python3", dlScript, "info", u];
    dlInfoProc.running = true;
  }

  function dlOnInfoLine(line) {
    if (dlStage !== "loading")
      return;

    if (line.indexOf("ERROR ") === 0) {
      dlTerminal = true;
      dlFail(line.slice(6));
      return;
    }

    if (line.indexOf("INFO ") !== 0)
      return;

    dlTerminal = true;

    let data = null;

    try {
      data = JSON.parse(line.slice(5));
    } catch (e) {
      dlFail("Resposta inesperada do yt-dlp.");
      return;
    }

    dlTitle = data.titulo || "";
    dlChannel = data.canal || "";
    dlDuration = data.aoVivo ? "ao vivo" : (data.duracao || "");
    dlOptions = data.formatos || [];
    dlSel = 0;
    dlMsg = data.aoVivo ? "Transmissão ao vivo: o download só termina quando ela acabar." : "";
    dlStage = "pick";
  }

  function dlFail(msg) {
    dlStage = "url";
    dlMsg = msg;
  }

  // ---------------- download ----------------

  function dlMove(d) {
    if (dlOptions.length === 0)
      return;

    dlSel = Math.max(0, Math.min(dlOptions.length - 1, dlSel + d));
  }

  function dlStart() {
    if (dlStage !== "pick" || dlOptions.length === 0 || dlRunProc.running)
      return;

    const o = dlOptions[dlSel];
    const cmd = ["python3", dlScript, "baixar", dlUrl, "--formato", String(o.id)];

    if (o.id === "audio")
      cmd.push("--audio");
    else if (o.temAudio)
      cmd.push("--tem-audio");

    dlPct = 0;
    dlSpeed = 0;
    dlEta = -1;
    dlStep = 1;
    dlSteps = (o.id === "audio" || o.temAudio) ? 1 : 2;
    dlStatus = "Iniciando…";
    dlMsg = "";
    dlLastErr = "";
    dlTerminal = false;
    dlCancelled = false;
    dlStage = "down";
    dlRunProc.command = cmd;
    dlRunProc.running = true;
  }

  function dlOnRunLine(line) {
    if (dlStage !== "down")
      return;

    if (line.indexOf("PROGRESS ") === 0) {
      const p = line.slice(9).split(" ");

      if (p.length >= 5) {
        dlPct = parseFloat(p[0]) || 0;
        dlSpeed = parseInt(p[1]) || 0;
        dlEta = parseInt(p[2]);
        dlStep = parseInt(p[3]) || 1;
        dlSteps = parseInt(p[4]) || dlSteps;
        dlStatus = dlSteps > 1 ? (dlStep === 1 ? "Baixando o vídeo…" : "Baixando o áudio…") : "Baixando…";
      }
    } else if (line.indexOf("STATUS ") === 0) {
      dlStatus = line.slice(7);

      if (dlStatus.indexOf("Juntando") === 0 || dlStatus.indexOf("Convert") === 0) {
        dlPct = 100;
        dlSpeed = 0;
        dlEta = -1;
      }
    } else if (line.indexOf("DONE ") === 0) {
      dlTerminal = true;
      dlFile = line.slice(5);
      dlPct = 100;
      dlStage = "done";
    } else if (line.indexOf("ERROR ") === 0) {
      dlTerminal = true;
      dlStage = "pick";
      dlMsg = line.slice(6);
    }
  }

  // o processo acabou sem DONE/ERROR/INFO (morreu, python quebrou…)
  function dlOnExit(code) {
    if (dlCancelled || dlTerminal)
      return;

    dlSettleTimer.restart();
  }

  function dlSettle() {
    if (dlCancelled || dlTerminal)
      return;

    const m = dlLastErr !== "" ? dlLastErr : "O yt-dlp terminou sem resposta. O python3 e o yt-dlp estão instalados?";

    if (dlStage === "loading")
      dlFail(m);
    else if (dlStage === "down") {
      dlStage = "pick";
      dlMsg = m;
    }
  }

  function dlCancel() {
    dlCancelled = true;
    dlSettleTimer.stop();

    if (dlInfoProc.running)
      dlInfoProc.running = false;

    if (dlRunProc.running)
      dlRunProc.running = false;

    if (dlStage === "loading") {
      dlStage = "url";
      dlMsg = "Busca cancelada.";
    } else if (dlStage === "down") {
      dlStage = "pick";
      dlMsg = "Download cancelado.";
    }
  }

  function dlOpenFolder() {
    if (dlFolder !== "")
      Quickshell.execDetached(["xdg-open", dlFolder]);
  }

  // ---------------- teclado ----------------

  function handleDlKey(e) {
    const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
    let ok = false;

    switch (dlStage) {
    case "url":     ok = dlUrlKey(e, ctrl);  break;
    case "pick":    ok = dlPickKey(e);       break;
    case "done":    ok = dlDoneKey(e);       break;
    default:        ok = dlBusyKey(e);       break;
    }

    if (ok)
      e.accepted = true;
  }

  function dlUrlKey(e, ctrl) {
    if (ctrl && e.key === Qt.Key_V) {
      dlPaste();
      return true;
    }

    switch (e.key) {
    case Qt.Key_Escape:
      phone.view = "menu";
      return true;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      dlFetch();
      return true;

    case Qt.Key_Backspace:
      dlSetUrl(dlUrl.slice(0, -1));
      return true;

    default:
      if (e.text && e.text.length === 1 && e.text > " ") {
        dlType(e.text);
        return true;
      }

      return false;
    }
  }

  function dlPickKey(e) {
    switch (e.key) {
    case Qt.Key_Escape:
      dlStage = "url";
      dlMsg = "";
      return true;

    case Qt.Key_Up:       dlMove(-1); return true;
    case Qt.Key_Down:     dlMove(1);  return true;
    case Qt.Key_PageUp:   dlMove(-4); return true;
    case Qt.Key_PageDown: dlMove(4);  return true;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      dlStart();
      return true;

    default:
      return false;
    }
  }

  function dlDoneKey(e) {
    switch (e.key) {
    case Qt.Key_Escape:
    case Qt.Key_N:
      dlNew();
      return true;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      dlOpenFolder();
      return true;

    default:
      return false;
    }
  }

  function dlBusyKey(e) {
    if (e.key === Qt.Key_Escape) {
      dlCancel();
      return true;
    }

    return false;
  }

  // ---------------- softkeys (chamadas pelo KeyControls) ----------------

  function dlLeftKey() {
    if (dlStage === "url")
      dlPaste();
    else if (dlStage === "done")
      dlNew();
  }

  function dlCenterKey() {
    if (dlStage === "url")
      dlFetch();
    else if (dlStage === "pick")
      dlStart();
    else if (dlStage === "done")
      dlOpenFolder();
  }

  function dlBack() {
    if (dlStage === "loading" || dlStage === "down")
      dlCancel();
    else if (dlStage === "pick") {
      dlStage = "url";
      dlMsg = "";
    } else if (dlStage === "done")
      dlNew();
    else
      phone.view = "menu";
  }

  function dlPaste() {
    if (!dlPasteProc.running)
      dlPasteProc.running = true;
  }

  // ---------------- processos ----------------

  Process {
    id: dlInfoProc

    stdout: SplitParser {
      onRead: (data) => phone.dl.dlOnInfoLine(data)
    }

    stderr: SplitParser {
      onRead: (data) => phone.dl.dlLastErr = data
    }

    onExited: (code, status) => phone.dl.dlOnExit(code)
  }

  Process {
    id: dlRunProc

    stdout: SplitParser {
      onRead: (data) => phone.dl.dlOnRunLine(data)
    }

    stderr: SplitParser {
      onRead: (data) => phone.dl.dlLastErr = data
    }

    onExited: (code, status) => phone.dl.dlOnExit(code)
  }

  // dá tempo das últimas linhas do stdout chegarem antes de decidir que falhou
  Timer {
    id: dlSettleTimer

    interval: 400

    onTriggered: phone.dl.dlSettle()
  }

  // Ctrl+V / softkey Colar
  Process {
    id: dlPasteProc

    command: ["wl-paste", "-n", "-t", "text"]

    stdout: StdioCollector {
      onStreamFinished: phone.dl.dlSetUrl(this.text.trim().replace(/\s+/g, "").slice(0, 600))
    }
  }
}
