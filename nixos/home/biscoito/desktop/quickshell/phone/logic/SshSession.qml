// logic/SshSession.qml — SSH: túnel, pastas, mini terminal, scp, senha no celular
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "ssh".
// Acesso de fora:  phone.ssh.<membro>

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // objetos usados por outros arquivos (acesso: phone.ssh.<nome>)
  property alias sshFileModel: sshFileModelObj
  property alias sshTermModel: sshTermModelObj

  // item da view registrado por ela mesma (Binding em views/SshView.qml)
  property var sshTermListRef: null

  // item da view registrado por ela mesma (Binding em views/SshView.qml)
  property var sshListRef: null

  // ================================================================
  // SSH — túnel CachyOS → Termux + navegador de pastas + mini terminal
  // (baseado na função tunel_ssh, só o sentido CachyOS → Termux)
  //
  // Parâmetros fixos: porta local 5000, porta 8023 no Termux, usuário
  // u0_a514 e chave ~/.ssh/termux_maya. O IP do Termux é informado na tela.
  //
  // Fluxo: form -> tunnel -> ready -> browser
  //   1. formulário (IP do Termux)
  //   2. confere chave e porta local, depois mantém `ssh -N` ativo
  //      (sem senha: BatchMode + chave)
  //   3. espera a porta local abrir e o Termux responder com banner SSH
  //   4. "Conectar?" -> um shell remoto persistente (também é o ControlMaster);
  //      as pastas e as transferências (scp) reaproveitam essa conexão
  //
  // StrictHostKeyChecking=yes, como na tunel_ssh: um IP novo precisa estar no
  // known_hosts; se não estiver, a tela mostra o comando para aceitar a chave.
  // ================================================================

  property string sshStage: "form"          // form | tunnel | ready | browser

  readonly property string sshDefaultTarget: ""

  property var sshFields: [sshDefaultTarget]

  property int sshFocus: 0

  readonly property var sshLabels: ["IP do Termux"]

  readonly property var sshHints: ["ex.: 192.168.2.25"]

  // parâmetros fixos da tunel_ssh (CachyOS → Termux)
  readonly property string sshLocal: "5000"

  readonly property string sshDest: "8023"          // porta do sshd no Termux (túnel e destino)

  readonly property string sshUser: "u0_a514"

  readonly property string sshLoop: "127.0.0.1"
  readonly property string sshClientHost: sshLoop

  readonly property string sshKey: (Quickshell.env("HOME") || "") + "/.ssh/termux_maya"

  // IP do Termux em uso (congelado ao abrir o túnel)
  property string sshHost: ""

  readonly property string sshHostFile:
    (Quickshell.env("XDG_STATE_HOME") || ((Quickshell.env("HOME") || "") + "/.local/state"))
    + "/quickshell-phone/ssh-host"

  property string sshMsg: ""                // erro/aviso mostrado na tela

  property string sshTunnelErr: ""

  property string sshShellErr: ""

  property int sshProbeTries: 0

  property bool sshTunnelStop: false

  property bool sshShellStop: false

  property bool sshShellUp: false

  property int sshBusy: 0

  property bool sshLsAgain: false

  property string sshListError: ""

  property string sshCwd: ""

  property string sshHome: ""

  property bool sshHidden: false

  property string sshMode: "files"          // files | term

  property int sshSel: 0

  property int sshMarked: 0

  property string sshStatus: ""

  property bool sshDlBusy: false

  property bool sshUpBusy: false

  property string sshInput: ""

  property var sshHist: []

  property int sshHistPos: -1

  property bool sshStick: true

  property bool sshOptOpen: false

  property int sshOptSel: 0

  readonly property string sshCtlPath:
    (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-phone-ssh-%C"

  // roda no destino antes do bash: vai pra home, avisa que o login deu certo
  // (marcador) e junta stderr no stdout
  readonly property string sshRemoteBoot:
    "exec sh -c 'cd; printf \"__QSEND__0:%s\\n\" \"$PWD\"; exec 2>&1; "
    + "if command -v bash >/dev/null 2>&1; then exec bash --noprofile --norc -s; else exec sh -s; fi'"

  readonly property string sshTarget: sshUser + "@" + sshHost

  // "ready" com aviso/erro: a view dá o espaço todo à mensagem
  readonly property bool sshReadyErr: sshStage === "ready" && sshMsg !== ""

  readonly property string sshTunnelCmd:
    "ssh -N -p " + sshDest + " -i ~/.ssh/termux_maya -L " + sshLoop + ":" + sshLocal
    + ":" + sshLoop + ":" + sshDest + " " + sshTarget

  // true enquanto o ssh autentica (barra de progresso)
  readonly property bool sshWaiting:
    phone.view === "ssh"
    && (sshStage === "tunnel" || (sshStage === "browser" && !sshShellUp))

  readonly property string sshCwdShort:
    (sshHome !== "" && sshCwd.indexOf(sshHome) === 0)
      ? "~" + sshCwd.slice(sshHome.length)
      : sshCwd

  readonly property string sshTitle:
    sshStage === "form" ? "SSH"
      : sshStage === "tunnel" ? "Abrindo túnel"
      : sshStage === "ready" ? "Túnel ativo"
      : !sshShellUp ? "Autenticando"
      : sshUser + "@" + sshHost

  readonly property string sshSubtitle:
    sshStage === "form" ? "Túnel CachyOS → Termux"
      : (sshStage === "browser" && sshShellUp)
        ? (sshMode === "term" ? "terminal · " + sshCwdShort : sshCwdShort)
        : sshClientHost + ":" + sshLocal + " → " + sshHost + ":" + sshDest

  // texto do botão do meio nas pastas: Abrir (pasta) / Marcar / Desmarcar
  readonly property string sshActText: {
    sshMarked;

    if (sshSel < 0 || sshSel >= sshFileModel.count)
      return "";

    const it = sshFileModel.get(sshSel);

    return it.isDir ? "Abrir" : (it.marked ? "Desmarcar" : "Marcar");
  }

  readonly property string sshSoftLeft:
    sshStage === "form" ? "Limpar"
      : sshStage === "ready" ? "Encerrar"
      : (sshStage === "browser" && sshShellUp) ? "Opções"
      : ""

  readonly property string sshSoftCenter: {
    if (sshStage === "form") return "Abrir túnel";
    if (sshStage === "ready") return "Conectar";

    if (sshStage === "browser" && sshShellUp)
      return sshMode === "term" ? "Enviar" : sshActText;

    return "";
  }

  readonly property string sshSoftRight: {
    if (sshStage === "tunnel") return "Cancelar";
    if (sshStage === "browser" && !sshShellUp) return "Cancelar";

    if (sshStage === "browser") {
      if (sshMode === "term") return "Pastas";

      if (sshCwd !== "" && sshCwd !== sshHome && sshCwd !== "/")
        return "Subir";
    }

    return "Voltar";
  }

  // opções do popup (softkey esquerda nas pastas/terminal)
  readonly property var sshOpts: {
    if (sshMode === "term") {
      return [
        { k: "files", t: "Pastas" },
        { k: "clear", t: "Limpar terminal" },
        { k: "disc",  t: "Desconectar" },
        { k: "kill",  t: "Encerrar túnel" }
      ];
    }

    return [
      { k: "term",   t: "Terminal" },
      { k: "dl",     t: sshMarked > 0 ? "Baixar marcados (" + sshMarked + ")" : "Baixar (marque arquivos)" },
      { k: "up",     t: "Enviar arquivos…" },
      { k: "hidden", t: sshHidden ? "Esconder ocultos" : "Mostrar ocultos" },
      { k: "unmark", t: "Desmarcar tudo" },
      { k: "disc",   t: "Desconectar" },
      { k: "kill",   t: "Encerrar túnel" }
    ];
  }

  ListModel {
    id: sshFileModelObj
  }

  ListModel {
    id: sshTermModelObj
  }

  onSshOptOpenChanged: {
    if (sshOptOpen)
      sshOptSel = 0;
  }

  onSshStageChanged: {
    sshOptOpen = false;

    if (phone.view === "ssh")
      phone.keyCatcher.forceActiveFocus();
  }

  onSshSelChanged: {
    if (phone.view === "ssh" && sshMode === "files")
      sshListRef?.positionViewAtIndex(sshSel, ListView.Contain);
  }

  // ---------------- utilidades ----------------

  function sshShq(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
  }

  function sshValidPort(s) {
    return /^\d+$/.test(s) && parseInt(s) >= 1 && parseInt(s) <= 65535;
  }

  function sshClean(s) {
    return String(s).replace(/\r/g, "").replace(/\x1b\[[0-9;?]*[ -\/]*[@-~]/g, "");
  }

  function sshSetField(i, v) {
    const a = sshFields.slice();

    a[i] = v;
    sshFields = a;
  }

  // texto digitado/colado: vai pro campo do formulário ou pro terminal
  function sshType(str) {
    if (!str)
      return;

    if (sshStage === "form") {
      // só caracteres de IP/host (números, letras, ponto e hífen)
      const t = String(str).replace(/[^A-Za-z0-9.-]/g, "");

      sshSetField(sshFocus, (sshFields[sshFocus] + t).slice(0, 63));
    } else if (sshStage === "browser" && sshShellUp && sshMode === "term") {
      sshInput += String(str).replace(/[\r\n]+/g, " ");
    }
  }

  // ---------------- túnel ----------------

  function sshValidIpv4(ip) {
    const parts = String(ip).split(".");
    return parts.length === 4 && parts.every(p => /^\d{1,3}$/.test(p) && Number(p) <= 255);
  }

  function sshSaveHost(h) {
    Quickshell.execDetached([
      "sh", "-c",
      'umask 077; mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"',
      "sh", sshHostFile, h
    ]);
  }

  function sshStartTunnel() {
    const hs = sshFields[0].trim();

    if (hs === "") {
      sshMsg = "Informe o IP do Termux (aparece no Wi-Fi do celular).";
      return;
    }

    if (!sshValidIpv4(hs)) {
      sshMsg = "IP do Termux inválido. Informe um IPv4, como 192.168.2.25.";
      return;
    }

    sshHost = hs;
    sshSaveHost(hs);

    sshMsg = "";
    sshTunnelErr = "";
    sshProbeTries = 0;
    sshStage = "tunnel";

    sshPreCheck();
  }

  // antes de abrir: a chave existe? a porta local está livre?
  //   10 = sem chave · 11 = porta ocupada
  function sshPreCheck() {
    sshPreProc.command = [
      "sh", "-c",
      '[ -f "$1" ] || exit 10; ss -H -ltn "sport = :$2" 2>/dev/null | grep -q . && exit 11; exit 0',
      "sh", sshKey, sshLocal
    ];

    sshPreProc.running = true;
  }

  function sshOnPreExit(code) {
    if (sshStage !== "tunnel")
      return;

    if (code === 10)
      sshFailTunnel("Chave não encontrada: ~/.ssh/termux_maya");
    else if (code === 11)
      sshFailTunnel("A porta local " + sshLocal + " já está ocupada (outro túnel?). Confira: ss -ltnp 'sport = :" + sshLocal + "'");
    else
      sshLaunchTunnel();
  }

  // traduz a última linha de erro do ssh; hop = "tunnel" (IP:8023) ou "shell" (127.0.0.1:5000)
  function sshExplain(raw, hop) {
    const l = String(raw);
    const alvo = hop === "shell" ? sshClientHost + ":" + sshLocal : sshHost + ":" + sshDest;
    const cmdKey = hop === "shell"
      ? "ssh -o StrictHostKeyChecking=accept-new -p " + sshLocal + " -i ~/.ssh/termux_maya " + sshUser + "@" + sshClientHost + " exit"
      : "ssh -o StrictHostKeyChecking=accept-new -p " + sshDest + " -i ~/.ssh/termux_maya " + sshTarget + " exit";

    if (/Host key verification failed|HOST IDENTIFICATION HAS CHANGED/i.test(l))
      return "A chave de " + alvo + " não está no known_hosts. Se for um IP novo, aceite uma vez no terminal: " + cmdKey;

    if (/Permission denied/i.test(l))
      return "O Termux não aceitou a chave ~/.ssh/termux_maya.";

    if (/Connection refused/i.test(l))
      return "Conexão recusada em " + alvo + ". O sshd do Termux está ligado?";

    if (/timed out|No route to host|Network is unreachable/i.test(l))
      return "Não consegui alcançar " + alvo + ". Confira o IP e o Wi-Fi.";

    if (/Could not resolve hostname/i.test(l))
      return "Não encontrei o endereço " + sshHost + ".";

    return l;
  }

  function sshLaunchTunnel() {
    sshTunnelProc.command = [
      "ssh", "-N",
      "-p", sshDest,
      "-o", "ExitOnForwardFailure=yes",
      "-o", "ConnectTimeout=10",
      "-o", "BatchMode=yes",
      "-o", "StrictHostKeyChecking=yes",
      "-o", "ServerAliveInterval=30",
      "-o", "ServerAliveCountMax=3",
      "-i", sshKey,
      "-L", sshLoop + ":" + sshLocal + ":" + sshLoop + ":" + sshDest,
      sshTarget
    ];

    sshProbeTries = 0;
    sshTunnelProc.running = true;
    sshProbeTimer.restart();
  }

  function sshStopTunnelProc() {
    sshProbeTimer.stop();

    if (sshTunnelProc.running) {
      sshTunnelStop = true;
      sshTunnelProc.running = false;
    }

  }

  function sshFailTunnel(msg) {
    sshProbeTimer.stop();
    sshStopTunnelProc();
    sshStage = "form";
    sshMsg = msg;
  }

  function sshTunnelReady(warn) {
    sshProbeTimer.stop();
    sshMsg = warn;
    sshStage = "ready";
  }

  function sshOnTunnelErr(raw) {
    const l = sshClean(raw).trim();

    if (l === "" || l.indexOf("Permanently added") >= 0)
      return;

    if (l.indexOf("open failed") >= 0)
      sshMsg = "O Termux não alcançou " + sshLoop + ":" + sshDest + ".";
    else
      sshTunnelErr = l;
  }

  function sshOnTunnelExit(code) {
    sshProbeTimer.stop();

    if (sshTunnelStop) {
      sshTunnelStop = false;
      return;
    }

    if (sshStage === "tunnel") {
      sshFailTunnel(
        sshTunnelErr !== ""
          ? sshExplain(sshTunnelErr, "tunnel")
          : "O ssh encerrou (código " + code + ") antes do túnel abrir."
      );
    } else if (sshStage !== "form") {
      sshStopShell();
      sshStage = "form";
      sshMsg = "O túnel caiu (código " + code + ").";
    }
  }

  function sshOnProbeExit(code) {
    if (sshStage !== "tunnel")
      return;

    if (code === 0)
      sshTunnelReady("");
    else if (code === 3)
      sshTunnelReady("Túnel aberto, mas o destino não mostrou banner SSH. Confira IP e porta.");
    // qualquer outro código = porta ainda fechada; o timer tenta de novo
  }

  function sshCloseAll() {
    sshProbeTimer.stop();
    sshStopShell();
    sshStopTunnelProc();
    sshMsg = "";
    sshStage = "form";
  }

  // ---------------- sessão no destino ----------------

  function sshConnectShell() {
    sshMsg = "";
    sshShellErr = "";
    sshShellUp = false;
    sshBusy = 0;
    sshCwd = "";
    sshHome = "";
    sshListError = "";
    sshLsAgain = false;
    sshInput = "";
    sshMode = "files";
    sshStatus = "";
    sshTermModel.clear();
    sshFileModel.clear();
    sshCountMarked();

    sshShellProc.command = [
      "ssh", "-p", sshLocal,
      "-i", sshKey,
      "-o", "BatchMode=yes",
      "-o", "StrictHostKeyChecking=yes",
      "-o", "ControlMaster=auto",
      "-o", "ControlPath=" + sshCtlPath,
      "-o", "ConnectTimeout=10",
      "-o", "ServerAliveInterval=30",
      sshUser + "@" + sshClientHost,
      sshRemoteBoot
    ];

    sshStage = "browser";
    sshShellProc.running = true;
  }

  function sshStopShell() {
    if (sshShellProc.running) {
      sshShellStop = true;
      sshShellProc.running = false;
    }

    sshShellUp = false;
  }

  function sshDisconnect() {
    sshStopShell();
    sshTermModel.clear();
    sshFileModel.clear();
    sshCountMarked();
    sshStage = "ready";
  }

  function sshOnShellExit(code) {
    if (sshShellStop) {
      sshShellStop = false;
      return;
    }

    const was = sshShellUp;

    sshShellUp = false;

    if (sshStage === "browser") {
      sshStage = "ready";
      sshMsg = was
        ? "A sessão SSH foi encerrada (código " + code + ")."
        : (sshShellErr !== "" ? sshExplain(sshShellErr, "shell") : "Não consegui autenticar em " + sshTarget + ".");
    }
  }

  function sshOnShellErr(raw) {
    const l = sshClean(raw).trim();

    if (l === "" || l.indexOf("Permanently added") >= 0)
      return;

    sshShellErr = l;

    if (sshShellUp)
      sshPushTerm("err", l);
  }

  function sshPushTerm(kind, txt) {
    if (sshTermModel.count > 500)
      sshTermModel.remove(0, 120);

    sshTermModel.append({ kind: kind, txt: txt });
  }

  // manda um comando ao shell; no fim ele imprime o marcador com
  // código de saída e diretório atual
  function sshShellRun(cmd, echo) {
    if (!sshShellProc.running || !sshShellUp)
      return;

    if (echo)
      sshPushTerm("cmd", sshUser + "@" + sshHost + ":" + sshCwdShort + "$ " + cmd);

    sshBusy++;
    sshShellProc.write(cmd + "\nprintf '__QSEND__%s:%s\\n' \"$?\" \"$PWD\"\n");
  }

  function sshOnShellLine(raw) {
    const line = sshClean(raw);
    const i = line.indexOf("__QSEND__");

    if (i < 0) {
      sshPushTerm("out", line);
      return;
    }

    const pre = line.slice(0, i);

    if (pre !== "")
      sshPushTerm("out", pre);

    const rest = line.slice(i + 9);
    const c = rest.indexOf(":");

    if (c < 0)
      return;

    sshOnShellDone(parseInt(rest.slice(0, c)), rest.slice(c + 1));
  }

  function sshOnShellDone(code, pwd) {
    const first = !sshShellUp;

    sshBusy = Math.max(0, sshBusy - (first ? 0 : 1));

    if (pwd !== sshCwd)
      sshSel = 0;

    sshCwd = pwd;

    if (first) {
      sshHome = pwd;
      sshShellUp = true;
      sshPushTerm("sys", "Conectado a " + sshTarget + " pelo túnel " + sshClientHost + ":" + sshLocal);
    } else if (code !== 0) {
      sshPushTerm("sys", "exit " + code);
    }

    sshRefreshList();
  }

  function sshSubmit() {
    const c = sshInput;

    if (c.trim() === "")
      return;

    sshHist.push(c);
    sshHistPos = -1;
    sshInput = "";
    sshStick = true;

    if (c.trim() === "clear") {
      sshTermModel.clear();
      return;
    }

    sshShellRun(c, true);
  }

  // ---------------- pastas ----------------

  function sshRefreshList() {
    if (!sshShellUp || sshCwd === "")
      return;

    if (sshLsProc.running) {
      sshLsAgain = true;
      return;
    }

    // BatchMode: só a conexão mestre; nunca abre prompt sozinho
    sshLsProc.command = [
      "ssh", "-p", sshLocal,
      "-i", sshKey,
      "-o", "BatchMode=yes",
      "-o", "StrictHostKeyChecking=yes",
      "-o", "ControlMaster=no",
      "-o", "ControlPath=" + sshCtlPath,
      sshUser + "@" + sshClientHost,
      "cd " + sshShq(sshCwd) + " && pwd && ls -1ApL"
    ];

    sshLsProc.running = true;
  }

  function sshParseLs(text) {
    const lines = text.split("\n");
    const dirs = [];
    const files = [];

    sshFileModel.clear();
    sshListError = "";

    if (text.trim() === "")
      sshListError = "Não consegui listar esta pasta.";

    for (let i = 1; i < lines.length; i++) {
      const l = lines[i];

      if (l === "")
        continue;

      if (l.endsWith("/")) {
        const d = l.slice(0, -1);

        if (sshHidden || d[0] !== ".")
          dirs.push(d);
      } else if (sshHidden || l[0] !== ".") {
        files.push(l);
      }
    }

    const cmp = (a, b) =>
      a.toLowerCase() < b.toLowerCase() ? -1 : (a.toLowerCase() > b.toLowerCase() ? 1 : 0);

    dirs.sort(cmp);
    files.sort(cmp);

    if (sshCwd !== "/")
      sshFileModel.append({ fname: "..", isDir: true, marked: false });

    for (const d of dirs)
      sshFileModel.append({ fname: d, isDir: true, marked: false });

    for (const f of files)
      sshFileModel.append({ fname: f, isDir: false, marked: false });

    sshSel = Math.max(0, Math.min(sshSel, sshFileModel.count - 1));
    sshCountMarked();
  }

  function sshCountMarked() {
    let n = 0;

    for (let i = 0; i < sshFileModel.count; i++) {
      if (sshFileModel.get(i).marked)
        n++;
    }

    sshMarked = n;
  }

  function sshToggleMark(i) {
    const it = sshFileModel.get(i);

    if (!it || it.isDir)
      return;

    sshFileModel.setProperty(i, "marked", !it.marked);
    sshStatus = "";
    sshCountMarked();
  }

  function sshClearMarks() {
    for (let i = 0; i < sshFileModel.count; i++) {
      if (sshFileModel.get(i).marked)
        sshFileModel.setProperty(i, "marked", false);
    }

    sshCountMarked();
  }

  function sshMoveSel(d) {
    const n = sshFileModel.count;

    if (n === 0)
      return;

    sshSel = Math.max(0, Math.min(n - 1, sshSel + d));
  }

  // Enter/Selecionar: pasta entra, arquivo marca/desmarca
  function sshActivate() {
    if (sshSel < 0 || sshSel >= sshFileModel.count)
      return;

    const it = sshFileModel.get(sshSel);

    if (it.isDir) {
      sshStatus = "";
      sshShellRun("cd -- " + sshShq(it.fname), false);
    } else {
      sshToggleMark(sshSel);
    }
  }

  // ---------------- transferências (scp, pela conexão mestre) ----------------

  function sshDownload() {
    if (sshDlBusy || !sshShellUp)
      return;

    if (sshMarked === 0) {
      sshStatus = "Marque arquivos primeiro (Enter/Marcar).";
      return;
    }

    const home = Quickshell.env("HOME") || "";
    const sources = [];

    for (let i = 0; i < sshFileModel.count; i++) {
      const it = sshFileModel.get(i);

      if (!it.isDir && it.marked) {
        const base = sshCwd.endsWith("/") ? sshCwd : sshCwd + "/";

        sources.push(sshUser + "@" + sshClientHost + ":" + base + it.fname);
      }
    }

    if (home === "" || sources.length === 0)
      return;

    sshDownloadProc.command = [
      "scp", "-P", sshLocal,
      "-i", sshKey,
      "-o", "BatchMode=yes",
      "-o", "StrictHostKeyChecking=yes",
      "-o", "ControlMaster=no",
      "-o", "ControlPath=" + sshCtlPath,
      "-o", "ConnectTimeout=15",
      ...sources,
      home + "/Downloads/"
    ];

    sshStatus = "Baixando " + sources.length + " arquivo(s) para ~/Downloads…";
    sshDlBusy = true;
    sshDownloadProc.running = true;
  }

  function sshOnDownloadExit(code) {
    sshDlBusy = false;

    if (code === 0) {
      sshStatus = "Download concluído em ~/Downloads.";
      sshClearMarks();
    } else {
      sshStatus = "Falha no download (código " + code + ").";
    }
  }

  // escolhe o arquivo no próprio "Meus arquivos" do celular
  function sshChooseUploads() {
    if (!sshShellUp || sshUpBusy)
      return;

    phone.files.filesPick = true;
    phone.files.filesPickUpload = true;
    phone.files.filesPickAi = false;
    phone.files.filesReturnView = "ssh";
    phone.files.filesDir = phone.files.homeDir;
    phone.view = "files";
  }

  function sshUpload(files) {
    if (!sshShellUp || sshUpBusy || !files || files.length === 0)
      return;

    const base = sshCwd.endsWith("/") ? sshCwd : sshCwd + "/";

    sshUploadProc.command = [
      "scp", "-P", sshLocal,
      "-i", sshKey,
      "-o", "BatchMode=yes",
      "-o", "StrictHostKeyChecking=yes",
      "-o", "ControlMaster=no",
      "-o", "ControlPath=" + sshCtlPath,
      "-o", "ConnectTimeout=15",
      ...files,
      sshUser + "@" + sshClientHost + ":" + base
    ];

    sshStatus = "Enviando " + files.length + " arquivo(s)…";
    sshUpBusy = true;
    sshUploadProc.running = true;
  }

  function sshOnUploadExit(code) {
    sshUpBusy = false;

    if (code === 0) {
      sshStatus = "Envio concluído.";
      sshRefreshList();
    } else {
      sshStatus = "Falha no envio (código " + code + ").";
    }
  }

  // ---------------- popup de opções ----------------

  function sshOptRun(k) {
    sshOptOpen = false;

    switch (k) {
    case "term":   sshMode = "term"; sshStick = true; break;
    case "files":  sshMode = "files"; break;
    case "clear":  sshTermModel.clear(); break;
    case "dl":     sshDownload(); break;
    case "up":     sshChooseUploads(); break;
    case "unmark": sshClearMarks(); break;
    case "disc":   sshDisconnect(); break;
    case "kill":   sshCloseAll(); break;

    case "hidden":
      sshHidden = !sshHidden;
      sshRefreshList();
      break;
    }
  }

  function handleSshOptKey(e) {
    const n = sshOpts.length;

    switch (e.key) {
    case Qt.Key_Up:    sshOptSel = (sshOptSel + n - 1) % n; break;
    case Qt.Key_Down:  sshOptSel = (sshOptSel + 1) % n;     break;

    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Right:
      sshOptRun(sshOpts[Math.min(sshOptSel, n - 1)].k);
      break;

    case Qt.Key_Escape:
    case Qt.Key_Left:
      sshOptOpen = false;
      break;

    default:
      return;
    }

    e.accepted = true;
  }

  // ---------------- teclado ----------------

  function sshEnter() {
    sshOptOpen = false;

  }

  function handleSshKey(e) {
    if (sshOptOpen) {
      handleSshOptKey(e);
      return;
    }

    const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
    let ok = true;

    if (ctrl && e.key === Qt.Key_V) {
      if (!sshPasteProc.running)
        sshPasteProc.running = true;
    } else if (sshStage === "form") {
      ok = sshFormKey(e);
    } else if (sshStage === "tunnel") {
      if (e.key === Qt.Key_Escape)
        sshCloseAll();
      else
        ok = false;
    } else if (sshStage === "ready") {
      ok = sshReadyKey(e);
    } else if (sshShellUp) {
      ok = sshMode === "term" ? sshTermKey(e, ctrl) : sshFilesKey(e, ctrl);
    } else if (e.key === Qt.Key_Escape) {
      sshDisconnect();
    } else {
      ok = false;
    }

    if (ok)
      e.accepted = true;
  }

  function sshFormKey(e) {
    switch (e.key) {
    case Qt.Key_Escape:
      phone.view = "menu";
      return true;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      sshStartTunnel();
      return true;

    case Qt.Key_Backspace:
      sshSetField(sshFocus, sshFields[sshFocus].slice(0, -1));
      return true;

    case Qt.Key_Up:
    case Qt.Key_Left:
      sshFocus = (sshFocus + sshFields.length - 1) % sshFields.length;
      return true;

    case Qt.Key_Down:
    case Qt.Key_Right:
      sshFocus = (sshFocus + 1) % sshFields.length;
      return true;

    default:
      if (e.text && e.text.length === 1 && e.text > " ") {
        sshType(e.text);
        return true;
      }

      return false;
    }
  }

  function sshReadyKey(e) {
    switch (e.key) {
    case Qt.Key_Return:
    case Qt.Key_Enter:
      sshConnectShell();
      return true;

    case Qt.Key_Escape:
      phone.view = "menu";
      return true;

    default:
      return false;
    }
  }

  function sshFilesKey(e, ctrl) {
    if (ctrl && e.key === Qt.Key_H) {
      sshOptRun("hidden");
      return true;
    }

    if (ctrl && e.key === Qt.Key_D) {
      sshDownload();
      return true;
    }

    if (ctrl && e.key === Qt.Key_U) {
      sshChooseUploads();
      return true;
    }

    switch (e.key) {
    case Qt.Key_Escape:
      sshBack();
      return true;

    case Qt.Key_Tab:
      sshMode = "term";
      sshStick = true;
      return true;

    case Qt.Key_Backspace:
    case Qt.Key_Left:
      sshStatus = "";
      sshShellRun("cd ..", false);
      return true;

    case Qt.Key_Right: {
      if (sshSel >= 0 && sshSel < sshFileModel.count && sshFileModel.get(sshSel).isDir)
        sshActivate();

      return true;
    }

    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Space:
      sshActivate();
      return true;

    case Qt.Key_Up:       sshMoveSel(-1); return true;
    case Qt.Key_Down:     sshMoveSel(1);  return true;
    case Qt.Key_PageUp:   sshMoveSel(-7); return true;
    case Qt.Key_PageDown: sshMoveSel(7);  return true;

    default:
      return false;
    }
  }

  function sshTermKey(e, ctrl) {
    if (ctrl && e.key === Qt.Key_L) {
      sshTermModel.clear();
      return true;
    }

    switch (e.key) {
    case Qt.Key_Escape:
    case Qt.Key_Tab:
      sshMode = "files";
      return true;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      sshSubmit();
      return true;

    case Qt.Key_Backspace:
      sshInput = sshInput.slice(0, -1);
      return true;

    case Qt.Key_Up:
      if (sshHist.length === 0)
        return true;

      sshHistPos = sshHistPos < 0 ? sshHist.length - 1 : Math.max(0, sshHistPos - 1);
      sshInput = sshHist[sshHistPos];
      return true;

    case Qt.Key_Down:
      if (sshHistPos < 0)
        return true;

      sshHistPos++;

      if (sshHistPos >= sshHist.length) {
        sshHistPos = -1;
        sshInput = "";
      } else {
        sshInput = sshHist[sshHistPos];
      }

      return true;

    case Qt.Key_PageUp:
      sshStick = false;
      sshTermListRef.contentY = Math.max(0, sshTermListRef.contentY - sshTermListRef.height * 0.8);
      return true;

    case Qt.Key_PageDown:
      sshTermListRef.contentY = Math.max(0, Math.min(
        sshTermListRef.contentHeight - sshTermListRef.height,
        sshTermListRef.contentY + sshTermListRef.height * 0.8
      ));

      sshStick = sshTermListRef.atYEnd;
      return true;

    default:
      if (e.text && e.text.length === 1 && e.text >= " ") {
        sshInput += e.text;
        return true;
      }

      return false;
    }
  }

  // ---------------- softkeys ----------------

  function sshLeftKey() {
    if (sshStage === "form")
      sshSetField(sshFocus, "");
    else if (sshStage === "ready")
      sshCloseAll();
    else if (sshStage === "browser" && sshShellUp)
      sshOptOpen = !sshOptOpen;
  }

  function sshCenterKey() {
    if (sshOptOpen) {
      sshOptRun(sshOpts[Math.min(sshOptSel, sshOpts.length - 1)].k);
      return;
    }

    if (sshStage === "form")
      sshStartTunnel();
    else if (sshStage === "ready")
      sshConnectShell();
    else if (sshStage === "browser" && sshShellUp) {
      if (sshMode === "term")
        sshSubmit();
      else
        sshActivate();
    }
  }

  function sshBack() {
    if (sshOptOpen) {
      sshOptOpen = false;
      return;
    }

    if (sshStage === "tunnel") {
      sshCloseAll();
      return;
    }

    if (sshStage === "browser" && !sshShellUp) {
      sshDisconnect();
      return;
    }

    if (sshStage === "browser") {
      if (sshMode === "term") {
        sshMode = "files";
        return;
      }

      if (sshCwd !== "" && sshCwd !== sshHome && sshCwd !== "/") {
        sshStatus = "";
        sshShellRun("cd ..", false);
        return;
      }
    }

    // sai do app, mas deixa túnel e sessão vivos
    phone.view = "menu";
  }

  // ---------------- processos ----------------

  Process {
    id: sshTunnelProc

    stderr: SplitParser {
      onRead: (data) => phone.ssh.sshOnTunnelErr(data)
    }

    onExited: (code, status) => phone.ssh.sshOnTunnelExit(code)
  }


  // antes de abrir o túnel: chave existe? porta local livre? (códigos em sshPreCheck)
  Process {
    id: sshPreProc

    onExited: (code, status) => phone.ssh.sshOnPreExit(code)
  }

  // último IP usado (salvo em ~/.local/state/quickshell-phone/ssh-host)
  Timer {
    interval: 80
    running: true

    onTriggered: sshLoadHostProc.running = true
  }

  Process {
    id: sshLoadHostProc

    command: ["sh", "-c", 'cat "$1" 2>/dev/null', "sh", phone.ssh.sshHostFile]

    stdout: StdioCollector {
      onStreamFinished: {
        const t = this.text.trim();

        if (phone.ssh.sshStage === "form" && phone.ssh.sshValidIpv4(t))
          phone.ssh.sshFields = [t];
      }
    }
  }

  // confere se a porta local abriu e se o destino responde como SSH
  //   0 = ok · 1 = porta ainda fechada · 3 = abriu, mas sem banner SSH
  Process {
    id: sshProbeProc

    command: [
      "bash", "-c",
      "exec 3<>/dev/tcp/127.0.0.1/$0; read -t 6 -u 3 l; case \"$l\" in SSH-*) exit 0;; esac; exit 3",
      phone.ssh.sshLocal
    ]

    onExited: (code, status) => phone.ssh.sshOnProbeExit(code)
  }

  Timer {
    id: sshProbeTimer

    interval: 700
    repeat: true

    onTriggered: {
      if (phone.ssh.sshStage !== "tunnel") {
        sshProbeTimer.stop();
        return;
      }

      phone.ssh.sshProbeTries++;

      if (phone.ssh.sshProbeTries > 400) {
        phone.ssh.sshFailTunnel("Tempo esgotado esperando o túnel abrir.");
        return;
      }

      if (!sshProbeProc.running)
        sshProbeProc.running = true;
    }
  }

  Process {
    id: sshShellProc

    stdinEnabled: true
    stdout: SplitParser {
      onRead: (data) => phone.ssh.sshOnShellLine(data)
    }

    stderr: SplitParser {
      onRead: (data) => phone.ssh.sshOnShellErr(data)
    }

    onExited: (code, status) => phone.ssh.sshOnShellExit(code)
  }

  Process {
    id: sshLsProc

    stdout: StdioCollector {
      onStreamFinished: phone.ssh.sshParseLs(this.text)
    }

    onExited: (code, status) => {
      if (phone.ssh.sshLsAgain) {
        phone.ssh.sshLsAgain = false;
        phone.ssh.sshRefreshList();
      }
    }
  }

  Process {
    id: sshDownloadProc

    stderr: SplitParser {
      onRead: (data) => {
        const l = phone.ssh.sshClean(data).trim();

        if (l !== "")
          phone.ssh.sshStatus = l;
      }
    }

    onExited: (code, status) => phone.ssh.sshOnDownloadExit(code)
  }

  Process {
    id: sshUploadProc

    stderr: SplitParser {
      onRead: (data) => {
        const l = phone.ssh.sshClean(data).trim();

        if (l !== "")
          phone.ssh.sshStatus = l;
      }
    }

    onExited: (code, status) => phone.ssh.sshOnUploadExit(code)
  }

  // Ctrl+V: cola o clipboard no campo/terminal
  Process {
    id: sshPasteProc

    command: ["wl-paste", "-n", "-t", "text"]

    stdout: StdioCollector {
      onStreamFinished: phone.ssh.sshType(this.text)
    }
  }
}
