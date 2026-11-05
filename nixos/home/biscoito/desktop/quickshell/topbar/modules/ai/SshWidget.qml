// SshWidget.qml — túnel SSH + navegador de pastas + mini terminal
//
// Mesmo molde do AiSidebar: abre no canto esquerdo, sob a topbar, controlado de fora
// por panelOpen / closeRequested(). Cores vêm do Colors.qml (matugen).
//
// Fluxo (é a função tunel_ssh() virada widget):
//   1. formulário: porta local, IP do destino, porta do destino, usuário, host/gateway
//   2. abre um túnel SSH destacado (`ssh -f -N -M`) com socket de controle próprio,
//      para sobreviver ao fechamento/destruição do painel; "Encerrar túnel" envia -O exit
//   3. espera a porta local abrir de verdade, conferindo o banner SSH do destino
//   3. "Conectar via SSH em usuario@ip?" -> abre `ssh -p porta_local usuario@localhost`
//      e troca pra tela com as pastas (em cima) e o mini terminal (embaixo)
//
// Como funciona o navegador + terminal:
//   - existe UM shell remoto persistente (bash -s, ou sh -s se não houver bash); ele
//     também é o ControlMaster do ssh. A listagem de pastas usa essa mesma conexão
//     (ControlPath), então não pede senha de novo
//   - clicar numa pasta manda `cd` pro shell; clicar num arquivo cola o nome no
//     terminal; o terminal manda o comando e, ao fim de cada um, o shell devolve o
//     diretório atual, que atualiza a lista. Uma fonte de verdade só: o cwd do shell
//   - sem TTY: vim, nano, top, htop e `sudo` sem -S não funcionam aqui
//
// Senhas/passphrases: SSH_ASKPASS aponta pra scripts/ssh/askpass.sh (zenity). Enquanto o
// ssh está autenticando, o painel vira "só o cartão clicável" pra janela do zenity
// aparecer por cima e receber o foco.
//
// Fechar/destruir o painel não derruba o túnel destacado. "Encerrar túnel" o finaliza;
// a sessão interativa do navegador, por outro lado, termina quando o widget é destruído.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../theme"

PanelWindow {
  id: sw

  required property var screenRef
  screen: screenRef

  property bool panelOpen: false
  property bool atBottom: false     // true no modo Windows 10
  property int topInset: 51         // altura da topbar
  property int bottomInset: 46      // altura da WinBar + folga
  property string nerdFont: "JetBrainsMono NF"
  property int moduleRadius: 20     // vem do shell.qml (root.moduleRadius)

  // ---------- configuração ----------
  property int panelWidth: 520
  property bool pinned: false
  property int leftPad: 0     // deslocamento horizontal (ex: largura do ToolRail)
  property string scriptDir: Quickshell.env("HOME") + "/.config/quickshell/topbar/scripts/ssh"
  readonly property string askpass: sw.scriptDir + "/askpass.sh"
  readonly property string ctlPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-ssh-%C"
  readonly property string tunnelCtlPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
    + "/qs-ssh-tunnel-" + sw.tLocal + "-" + sw.tUser.replace(/[^A-Za-z0-9_.-]/g, "_").slice(0, 8)
    + "-" + sw.tHost.replace(/[^A-Za-z0-9_.-]/g, "_").slice(0, 12)

  // roda no shell do destino antes do bash: vai pra home, avisa o widget que o login
  // deu certo (marcador) e junta stderr no stdout
  readonly property string remoteBoot:
    "exec sh -c 'cd; printf \"__QSEND__0:%s\\n\" \"$PWD\"; exec 2>&1; "
    + "if command -v bash >/dev/null 2>&1; then exec bash --noprofile --norc -s; else exec sh -s; fi'"

  readonly property var sshEnv: ({
    "SSH_ASKPASS": sw.askpass,
    "SSH_ASKPASS_REQUIRE": "force"
  })

  signal closeRequested()

  visible: panelOpen
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  // fixado OU esperando o ssh autenticar: só o cartão recebe cliques e o resto da
  // tela fica livre (é isso que deixa o zenity aparecer e ser clicado)
  readonly property bool passthrough: sw.pinned || sw.waiting

  anchors {
    top: true
    bottom: true
    left: true
    right: !sw.passthrough
  }

  implicitWidth: sw.passthrough ? sw.panelWidth + 16 : 0

  mask: sw.passthrough ? pinRegion : null

  Region {
    id: pinRegion

    item: card
  }

  WlrLayershell.layer: sw.passthrough ? WlrLayer.Top : WlrLayer.Overlay
  WlrLayershell.keyboardFocus: !sw.panelOpen
    ? WlrKeyboardFocus.None
    : (sw.waiting
      ? WlrKeyboardFocus.None
      : (sw.pinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive))
  WlrLayershell.namespace: "quickshell:ssh"

  // ================================================================
  // CORES — MATUGEN
  // ================================================================

  readonly property color cBg: Colors.md3.surface_container
  readonly property color cItem: Colors.md3.surface_container_high
  readonly property color cItemHi: Colors.md3.surface_container_highest
  readonly property color cText: Colors.md3.source_color
  readonly property color cMuted: Colors.md3.outline
  readonly property color cLine: Colors.md3.outline_variant
  readonly property color cAccent: Colors.md3.primary
  readonly property color cOnAccent: Colors.md3.on_primary
  readonly property color cError: Colors.md3.error
  readonly property color cBody: Colors.md3.on_surface

  readonly property bool darkUi: sw.cBg.hslLightness < 0.5
  readonly property color cTerm: Qt.darker(sw.cBg, sw.darkUi ? 1.35 : 1.05)

  // ================================================================
  // ESTADO
  // ================================================================

  // form -> tunnel -> ready -> browser
  property string stage: "form"

  // valores usados pelo túnel em andamento (congelados ao clicar em "Abrir túnel")
  property string tLocal: ""
  property string tIp: ""
  property string tDest: ""
  property string tUser: ""
  property string tHost: ""

  property string formError: ""
  property string notice: ""
  property string tunnelErr: ""
  property string tunnelWarn: ""
  property string shellErr: ""

  property int probeTries: 0
  property bool tunnelStop: false     // matamos o ssh do túnel de propósito
  property bool shellStop: false      // matamos o shell de propósito
  property bool shellUp: false
  property int busyCmds: 0
  property bool lsAgain: false
  property string listError: ""
  property string downloadStatus: ""
  property bool downloadBusy: false
  property string uploadStatus: ""
  property bool uploadBusy: false

  property string cwd: ""
  property string homeDir: ""
  property bool showHidden: false
  property bool stickTerm: true
  property real splitFrac: 0.5
  property var hist: []
  property int histPos: -1
  property real slide: 1

  readonly property string sshTarget: sw.tUser + "@" + sw.tHost
  readonly property string tunnelCmd: "ssh -N -L " + sw.tLocal + ":" + sw.tIp + ":" + sw.tDest
    + " " + sw.tUser + "@" + sw.tHost

  readonly property bool waiting: sw.stage === "tunnel" || (sw.stage === "browser" && !sw.shellUp)

  readonly property string cwdShort: (sw.homeDir !== "" && sw.cwd.indexOf(sw.homeDir) === 0)
    ? "~" + sw.cwd.slice(sw.homeDir.length)
    : sw.cwd

  readonly property string headerTitle: sw.stage === "form"
    ? "Túnel SSH"
    : (sw.stage === "browser" && sw.shellUp
      ? sw.tUser + "@" + sw.tIp
      : "localhost:" + sw.tLocal + " → " + sw.tIp + ":" + sw.tDest)

  readonly property string banner: sw.stage === "form"
    ? sw.formError
    : (sw.stage === "ready" ? (sw.notice !== "" ? sw.notice : sw.tunnelWarn) : "")

  ListModel {
    id: termModel
  }

  ListModel {
    id: fileModel
  }

  NumberAnimation {
    id: slideAnim

    target: sw
    property: "slide"
    from: 0
    to: 1
    duration: 190
    easing.type: Easing.OutCubic
  }

  onPanelOpenChanged: {
    if (sw.panelOpen) {
      slideAnim.restart();
      Qt.callLater(sw.focusMain);

      // Se o painel foi fechado sem encerrar o túnel destacado (-f -N -M),
      // o processo ssh ainda está vivo no sistema. Ao reabrir, verifica o socket
      // de controle e, se o túnel responder, pula direto pra "ready".
      if (sw.stage === "ready" && sw.tLocal !== "") {
        tunnelCheckProc.command = [
          "ssh", "-S", sw.tunnelCtlPath, "-O", "check", sw.tUser + "@" + sw.tHost
        ];
        tunnelCheckProc.running = true;
      }
    }
  }

  onStageChanged: Qt.callLater(sw.focusMain)
  onShellUpChanged: Qt.callLater(sw.focusMain)

  // ================================================================
  // LÓGICA
  // ================================================================

  function focusMain() {
    if (sw.stage === "form") {
      fLocal.input.forceActiveFocus();
    } else if (sw.stage === "browser" && sw.shellUp) {
      termInput.forceActiveFocus();
    } else {
      rootItem.forceActiveFocus();
    }
  }

  // aspas simples pro shell remoto
  function shq(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
  }

  function validPort(s) {
    return /^\d+$/.test(s) && parseInt(s) >= 1 && parseInt(s) <= 65535;
  }

  function cleanLine(s) {
    return String(s).replace(/\r/g, "").replace(/\x1b\[[0-9;?]*[ -\/]*[@-~]/g, "");
  }

  // ---------- túnel ----------

  function startTunnel() {
    const lp = fLocal.text.trim();
    const ip = fIp.text.trim();
    const dp = fDest.text.trim();
    const us = fUser.text.trim();
    const hs = fHost.text.trim();

    if (!sw.validPort(lp) || !sw.validPort(dp)) {
      sw.formError = "As portas precisam ser números entre 1 e 65535.";
      return;
    }

    if (ip === "" || us === "" || hs === "") {
      sw.formError = "Preencha IP do destino, usuário e host/gateway.";
      return;
    }

    if (/\s/.test(ip + us + hs) || ip[0] === "-" || hs[0] === "-" || us[0] === "-") {
      sw.formError = "IP, usuário e host não podem ter espaços nem começar com “-”.";
      return;
    }

    sw.tLocal = lp;
    sw.tIp = ip;
    sw.tDest = dp;
    sw.tUser = us;
    sw.tHost = hs;

    sw.formError = "";
    sw.notice = "";
    sw.tunnelErr = "";
    sw.tunnelWarn = "";
    sw.probeTries = 0;
    sw.stage = "tunnel";

    // Se o painel foi destruído/reaberto, reutiliza o túnel destacado que já existe.
    tunnelCheckProc.command = [
      "ssh", "-S", sw.tunnelCtlPath, "-O", "check", us + "@" + hs
    ];
    tunnelCheckProc.running = true;
  }

  function launchDetachedTunnel() {
    tunnelProc.command = [
      "ssh", "-f", "-N", "-M",
      "-S", sw.tunnelCtlPath,
      "-o", "ExitOnForwardFailure=yes",
      "-o", "ConnectTimeout=15",
      "-o", "ServerAliveInterval=30",
      "-o", "ServerAliveCountMax=3",
      "-o", "StrictHostKeyChecking=accept-new",
      "-L", sw.tLocal + ":" + sw.tIp + ":" + sw.tDest,
      sw.tUser + "@" + sw.tHost
    ];

    sw.probeTries = 0;
    tunnelProc.running = true;
    probeTimer.restart();
  }

  function onTunnelCheckExit(code) {
    if (code === 0) {
      // Túnel ainda vivo: vai direto pra "ready", seja vindo de "tunnel"
      // (primeira vez) ou de "ready" (reabertura do painel).
      sw.tunnelReady("");
    } else if (sw.stage === "tunnel") {
      // Só lança um novo túnel se estávamos esperando um.
      sw.launchDetachedTunnel();
    } else {
      // Veio da verificação de reabertura e o túnel já morreu: volta pro form.
      sw.stage = "form";
      sw.notice = "";
      sw.formError = "O túnel expirou enquanto o painel estava fechado.";
    }
  }

  function stopTunnelProc() {
    probeTimer.stop();

    if (tunnelProc.running) {
      sw.tunnelStop = true;
      tunnelProc.running = false;
    }

    // O processo SSH está destacado do widget; encerra-o pelo socket de controle.
    if (sw.tLocal !== "" && sw.tUser !== "" && sw.tHost !== "") {
      tunnelStopProc.command = [
        "ssh", "-S", sw.tunnelCtlPath, "-O", "exit", sw.tUser + "@" + sw.tHost
      ];
      tunnelStopProc.running = true;
    }
  }

  function failTunnel(msg) {
    probeTimer.stop();
    sw.stopTunnelProc();
    sw.stage = "form";
    sw.formError = msg;
  }

  function tunnelReady(warn) {
    probeTimer.stop();
    sw.tunnelWarn = warn;
    sw.stage = "ready";
  }

  function onTunnelErr(raw) {
    const l = sw.cleanLine(raw).trim();

    if (l === "" || l.indexOf("Permanently added") >= 0) {
      return;
    }

    if (l.indexOf("open failed") >= 0) {
      sw.tunnelWarn = "O gateway não conseguiu alcançar " + sw.tIp + ":" + sw.tDest + ".";
    } else {
      sw.tunnelErr = l;
    }
  }

  function onTunnelExit(code) {
    probeTimer.stop();

    if (sw.tunnelStop) {
      sw.tunnelStop = false;
      return;
    }

    if (sw.stage === "tunnel") {
      // Com -f, o ssh pai termina após autenticar; o túnel segue em segundo plano.
      if (code !== 0) {
        sw.failTunnel(sw.tunnelErr !== ""
          ? sw.tunnelErr
          : "O ssh terminou (código " + code + ") antes do túnel abrir.");
      }
    } else if (sw.stage !== "form") {
      sw.stopShell();
      sw.stage = "form";
      sw.formError = "O túnel caiu (código " + code + ").";
    }
  }

  function onProbeExit(code) {
    if (sw.stage !== "tunnel") {
      return;
    }

    if (code === 0) {
      sw.tunnelReady("");
    } else if (code === 3) {
      sw.tunnelReady("O túnel abriu, mas o destino não mostrou um banner SSH. Confira IP e porta.");
    }
    // qualquer outro código = porta local ainda fechada; o timer tenta de novo
  }

  function closeAll() {
    probeTimer.stop();
    sw.stopShell();
    sw.stopTunnelProc();
    sw.notice = "";
    sw.tunnelWarn = "";
    sw.stage = "form";
  }

  // ---------- sessão no destino ----------

  function connectShell() {
    sw.notice = "";
    sw.shellErr = "";
    sw.shellUp = false;
    sw.busyCmds = 0;
    sw.cwd = "";
    sw.homeDir = "";
    sw.listError = "";
    sw.lsAgain = false;
    termModel.clear();
    fileModel.clear();

    shellProc.command = [
      "ssh", "-p", sw.tLocal,
      "-o", "StrictHostKeyChecking=accept-new",
      "-o", "HostKeyAlias=" + sw.tIp,
      "-o", "ControlMaster=auto",
      "-o", "ControlPath=" + sw.ctlPath,
      "-o", "ConnectTimeout=15",
      "-o", "ServerAliveInterval=30",
      sw.tUser + "@localhost",
      sw.remoteBoot
    ];

    sw.stage = "browser";
    shellProc.running = true;
  }

  function stopShell() {
    if (shellProc.running) {
      sw.shellStop = true;
      shellProc.running = false;
    }

    sw.shellUp = false;
  }

  function disconnectShell() {
    sw.stopShell();
    termModel.clear();
    fileModel.clear();
    sw.stage = "ready";
  }

  function onShellExit(code) {
    if (sw.shellStop) {
      sw.shellStop = false;
      return;
    }

    const was = sw.shellUp;

    sw.shellUp = false;

    if (sw.stage === "browser") {
      sw.stage = "ready";
      sw.notice = was
        ? "A sessão SSH foi encerrada (código " + code + ")."
        : (sw.shellErr !== "" ? sw.shellErr : "Não consegui autenticar em " + sw.sshTarget + ".");
    }
  }

  function onShellErr(raw) {
    const l = sw.cleanLine(raw).trim();

    if (l === "" || l.indexOf("Permanently added") >= 0) {
      return;
    }

    sw.shellErr = l;

    if (sw.shellUp) {
      sw.pushTerm("err", l);
    }
  }

  function pushTerm(kind, txt) {
    if (termModel.count > 700) {
      termModel.remove(0, 150);
    }

    termModel.append({ kind: kind, txt: txt });
  }

  // manda um comando ao shell; ao fim dele o shell imprime o marcador com
  // código de saída e diretório atual
  function shellRun(cmd, echo) {
    if (!shellProc.running || !sw.shellUp) {
      return;
    }

    if (echo) {
      sw.pushTerm("cmd", sw.tUser + "@" + sw.tIp + ":" + sw.cwdShort + "$ " + cmd);
    }

    sw.busyCmds++;
    shellProc.write(cmd + "\nprintf '__QSEND__%s:%s\\n' \"$?\" \"$PWD\"\n");
  }

  function onShellLine(raw) {
    const line = sw.cleanLine(raw);
    const i = line.indexOf("__QSEND__");

    if (i < 0) {
      sw.pushTerm("out", line);
      return;
    }

    const pre = line.slice(0, i);

    if (pre !== "") {
      sw.pushTerm("out", pre);
    }

    const rest = line.slice(i + 9);
    const c = rest.indexOf(":");

    if (c < 0) {
      return;
    }

    sw.onShellDone(parseInt(rest.slice(0, c)), rest.slice(c + 1));
  }

  function onShellDone(code, pwd) {
    const first = !sw.shellUp;

    sw.busyCmds = Math.max(0, sw.busyCmds - (first ? 0 : 1));
    sw.cwd = pwd;

    if (first) {
      sw.homeDir = pwd;
      sw.shellUp = true;
      sw.pushTerm("sys", "Conectado a " + sw.sshTarget + " pelo túnel localhost:" + sw.tLocal);
    } else if (code !== 0) {
      sw.pushTerm("sys", "exit " + code);
    }

    sw.refreshList();
  }

  function submitCmd() {
    const c = termInput.text;

    if (c.trim() === "") {
      return;
    }

    sw.hist.push(c);
    sw.histPos = -1;
    termInput.text = "";
    sw.stickTerm = true;

    if (c.trim() === "clear") {
      termModel.clear();
      return;
    }

    sw.shellRun(c, true);
  }

  // ---------- lista de pastas ----------

  function refreshList() {
    if (!sw.shellUp || sw.cwd === "") {
      return;
    }

    if (lsProc.running) {
      sw.lsAgain = true;
      return;
    }

    // BatchMode: usa só a conexão mestre; nunca abre prompt de senha por conta própria
    lsProc.command = [
      "ssh", "-p", sw.tLocal,
      "-o", "BatchMode=yes",
      "-o", "StrictHostKeyChecking=accept-new",
      "-o", "HostKeyAlias=" + sw.tIp,
      "-o", "ControlMaster=no",
      "-o", "ControlPath=" + sw.ctlPath,
      sw.tUser + "@localhost",
      "cd " + sw.shq(sw.cwd) + " && pwd && ls -1ApL"
    ];

    lsProc.running = true;
  }

  function parseLs(text) {
    const lines = text.split("\n");
    const dirs = [];
    const files = [];

    fileModel.clear();
    sw.listError = "";

    if (text.trim() === "") {
      sw.listError = "Não consegui listar esta pasta.";
    }

    for (let i = 1; i < lines.length; i++) {
      const l = lines[i];

      if (l === "") {
        continue;
      }

      if (l.endsWith("/")) {
        const d = l.slice(0, -1);

        if (sw.showHidden || d[0] !== ".") {
          dirs.push(d);
        }
      } else if (sw.showHidden || l[0] !== ".") {
        files.push(l);
      }
    }

    const cmp = (a, b) => a.toLowerCase() < b.toLowerCase() ? -1 : (a.toLowerCase() > b.toLowerCase() ? 1 : 0);

    dirs.sort(cmp);
    files.sort(cmp);

    if (sw.cwd !== "/") {
      fileModel.append({ fname: "..", isDir: true, selected: false });
    }

    for (const d of dirs) {
      fileModel.append({ fname: d, isDir: true, selected: false });
    }

    for (const f of files) {
      fileModel.append({ fname: f, isDir: false, selected: false });
    }
  }

  function selectedCount() {
    let count = 0;
    for (let i = 0; i < fileModel.count; i++) {
      const item = fileModel.get(i);
      if (!item.isDir && item.selected) count++;
    }
    return count;
  }

  function toggleFileSelection(name) {
    for (let i = 0; i < fileModel.count; i++) {
      const item = fileModel.get(i);
      if (!item.isDir && item.fname === name) {
        fileModel.setProperty(i, "selected", !item.selected);
        sw.downloadStatus = "";
        return;
      }
    }
  }

  function clearFileSelection() {
    for (let i = 0; i < fileModel.count; i++) {
      if (fileModel.get(i).selected) fileModel.setProperty(i, "selected", false);
    }
  }

  function downloadSelected() {
    if (sw.downloadBusy || sw.selectedCount() === 0 || !sw.shellUp) return;

    const home = Quickshell.env("HOME") || "";
    if (home === "") {
      sw.downloadStatus = "Não consegui localizar sua pasta pessoal.";
      return;
    }

    const sources = [];
    for (let i = 0; i < fileModel.count; i++) {
      const item = fileModel.get(i);
      if (!item.isDir && item.selected) {
        const remotePath = (sw.cwd.endsWith("/") ? sw.cwd : sw.cwd + "/") + item.fname;
        sources.push(sw.tUser + "@localhost:" + remotePath);
      }
    }

    if (sources.length === 0) return;

    downloadProc.command = [
      "scp", "-P", sw.tLocal,
      "-o", "BatchMode=no",
      "-o", "HostKeyAlias=" + sw.tIp,
      "-o", "ControlMaster=no",
      "-o", "ControlPath=" + sw.ctlPath,
      "-o", "ConnectTimeout=15",
      ...sources,
      home + "/Downloads/"
    ];

    sw.downloadStatus = "Baixando " + sources.length + " arquivo(s) para ~/Downloads…";
    sw.downloadBusy = true;
    downloadProc.running = true;
  }

  function onDownloadExit(code) {
    sw.downloadBusy = false;
    if (code === 0) {
      sw.downloadStatus = "Download concluído em ~/Downloads.";
      sw.clearFileSelection();
    } else {
      sw.downloadStatus = "Falha no download (código " + code + "). Confira a conexão e as permissões.";
    }
  }


  function chooseUploads() {
    // FileDialog nativo trava no Wayland com WlrKeyboardFocus.Exclusive.
    // Usamos zenity igual ao askpass.sh: processo externo, sem conflito de foco.
    if (!sw.shellUp || sw.uploadBusy || filePickerProc.running) return;
    filePickerProc.command = [
      "zenity", "--file-selection", "--multiple",
      "--separator=\n",
      "--title=Selecionar arquivos para enviar a " + sw.tUser + "@" + sw.tIp
    ];
    filePickerProc.running = true;
  }

  function uploadFiles(localFiles) {
    if (!sw.shellUp || sw.uploadBusy || !localFiles || localFiles.length === 0) return;
    if (localFiles.length === 0) {
      sw.uploadStatus = "Nenhum arquivo selecionado.";
      return;
    }

    const remoteDir = sw.cwd.endsWith("/") ? sw.cwd : sw.cwd + "/";
    uploadProc.command = [
      "scp", "-P", sw.tLocal,
      "-o", "BatchMode=no",
      "-o", "HostKeyAlias=" + sw.tIp,
      "-o", "ControlMaster=no",
      "-o", "ControlPath=" + sw.ctlPath,
      "-o", "ConnectTimeout=15",
      ...localFiles,
      sw.tUser + "@localhost:" + remoteDir
    ];

    sw.uploadStatus = "Enviando " + localFiles.length + " arquivo(s) para " + sw.cwd + "…";
    sw.uploadBusy = true;
    uploadProc.running = true;
  }

  function onUploadExit(code) {
    sw.uploadBusy = false;
    if (code === 0) {
      sw.uploadStatus = "Envio concluído para " + sw.cwd + ".";
      sw.refreshList();
    } else {
      sw.uploadStatus = "Falha no envio (código " + code + "). Confira a conexão e as permissões.";
    }
  }

  function openEntry(name, isDir) {
    if (isDir) {
      sw.downloadStatus = "";
      sw.shellRun("cd -- " + sw.shq(name), false);
    } else {
      sw.toggleFileSelection(name);
    }
  }

  // ================================================================
  // PROCESSOS
  // ================================================================

  Process {
    id: tunnelProc

    environment: sw.sshEnv

    stderr: SplitParser {
      onRead: (data) => sw.onTunnelErr(data)
    }

    onExited: (code, status) => sw.onTunnelExit(code)
  }

  Process {
    id: tunnelCheckProc
    environment: sw.sshEnv
    onExited: (code, status) => sw.onTunnelCheckExit(code)
  }

  Process {
    id: tunnelStopProc
    environment: sw.sshEnv
  }

  // confere se a porta local abriu e se o destino responde com banner SSH
  //   0 = ok · 1 = porta ainda fechada · 3 = abriu, mas sem banner SSH
  Process {
    id: probeProc

    command: [
      "bash", "-c",
      "exec 3<>/dev/tcp/127.0.0.1/$0; read -t 6 -u 3 l; case \"$l\" in SSH-*) exit 0;; esac; exit 3",
      sw.tLocal
    ]

    onExited: (code, status) => sw.onProbeExit(code)
  }

  Timer {
    id: probeTimer

    interval: 700
    repeat: true

    onTriggered: {
      if (sw.stage !== "tunnel") {
        probeTimer.stop();
        return;
      }

      sw.probeTries++;

      if (sw.probeTries > 400) {
        sw.failTunnel("Tempo esgotado esperando o túnel abrir.");
        return;
      }

      if (!probeProc.running) {
        probeProc.running = true;
      }
    }
  }

  Process {
    id: shellProc

    stdinEnabled: true
    environment: sw.sshEnv

    stdout: SplitParser {
      onRead: (data) => sw.onShellLine(data)
    }

    stderr: SplitParser {
      onRead: (data) => sw.onShellErr(data)
    }

    onExited: (code, status) => sw.onShellExit(code)
  }

  Process {
    id: lsProc

    stdout: StdioCollector {
      onStreamFinished: sw.parseLs(this.text)
    }

    onExited: (code, status) => {
      if (sw.lsAgain) {
        sw.lsAgain = false;
        sw.refreshList();
      }
    }
  }

  Process {
    id: downloadProc

    environment: sw.sshEnv

    stderr: SplitParser {
      onRead: (data) => {
        const line = sw.cleanLine(data).trim();
        if (line !== "") sw.downloadStatus = line;
      }
    }

    onExited: (code, status) => sw.onDownloadExit(code)
  }

  Process {
    id: uploadProc

    environment: sw.sshEnv

    stderr: SplitParser {
      onRead: (data) => {
        const line = sw.cleanLine(data).trim();
        if (line !== "") sw.uploadStatus = line;
      }
    }

    onExited: (code, status) => sw.onUploadExit(code)
  }

  // Seletor de arquivo via zenity — funciona no Wayland sem conflito de foco,
  // ao contrário do FileDialog nativo do Qt com WlrKeyboardFocus.Exclusive.
  Process {
    id: filePickerProc

    stdout: StdioCollector {
      onStreamFinished: {
        const paths = this.text.trim().split("\n").filter(p => p !== "");
        if (paths.length > 0) sw.uploadFiles(paths);
      }
    }
  }

  // ================================================================
  // COMPONENTES
  // ================================================================

  component Glyph: Text {
    font.family: sw.nerdFont
    font.pixelSize: 16
    color: sw.cText
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  component Label: Text {
    font.family: sw.nerdFont
    font.pixelSize: 12
    color: sw.cText
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
  }

  component RoundBtn: Rectangle {
    id: rb

    property string glyph: ""
    property bool active: false
    property bool primary: false

    signal clicked()

    implicitWidth: 32
    implicitHeight: 32
    radius: width / 2
    color: rb.primary || rb.active
      ? (rbArea.containsMouse ? Qt.lighter(sw.cAccent, 1.1) : sw.cAccent)
      : (rbArea.containsMouse ? sw.cItemHi : sw.cItem)

    Glyph {
      anchors.centerIn: parent
      text: rb.glyph
      color: (rb.primary || rb.active) ? sw.cOnAccent : sw.cText
      font.pixelSize: 13
    }

    MouseArea {
      id: rbArea

      anchors.fill: parent
      hoverEnabled: true
      onClicked: rb.clicked()
    }
  }

  component PillBtn: Rectangle {
    id: pb

    property string text: ""
    property string glyph: ""
    property bool primary: false

    signal clicked()

    implicitHeight: 38
    implicitWidth: pbRow.implicitWidth + 32
    radius: height / 2
    color: pb.primary
      ? (pbArea.containsMouse ? Qt.lighter(sw.cAccent, 1.1) : sw.cAccent)
      : (pbArea.containsMouse ? sw.cItemHi : sw.cItem)

    Row {
      id: pbRow

      anchors.centerIn: parent
      spacing: 8

      Glyph {
        visible: pb.glyph !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: pb.glyph
        color: pb.primary ? sw.cOnAccent : sw.cText
        font.pixelSize: 13
      }

      Label {
        anchors.verticalCenter: parent.verticalCenter
        text: pb.text
        font.bold: true
        color: pb.primary ? sw.cOnAccent : sw.cText
      }
    }

    MouseArea {
      id: pbArea

      anchors.fill: parent
      hoverEnabled: true
      onClicked: pb.clicked()
    }
  }

  component Spinner: Glyph {
    id: spin

    text: "\uf110" // spinner
    color: sw.cAccent

    RotationAnimator on rotation {
      from: 0
      to: 360
      duration: 900
      loops: Animation.Infinite
      running: spin.visible
    }
  }

  // campo do formulário, no estilo do prompt "➜ Porta local ›" da função original
  component Field: Rectangle {
    id: fld

    property string label: ""
    property string placeholder: ""
    property bool numeric: false
    property Item tabTarget: null
    property alias text: ti.text
    property alias input: ti

    signal submitted()

    Layout.fillWidth: true
    implicitHeight: 40
    radius: 20
    color: ti.activeFocus ? sw.cItemHi : sw.cItem
    border.width: ti.activeFocus ? 1 : 0
    border.color: sw.cAccent

    IntValidator {
      id: intV

      bottom: 1
      top: 65535
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      spacing: 8

      Glyph {
        text: "\uf061" // arrow-right
        color: sw.cAccent
        font.pixelSize: 11
      }

      Label {
        text: fld.label
        color: sw.cMuted
        font.pixelSize: 11
        Layout.preferredWidth: 112
      }

      TextInput {
        id: ti

        Layout.fillWidth: true
        color: sw.cText
        selectionColor: sw.cAccent
        selectedTextColor: sw.cOnAccent
        font.family: sw.nerdFont
        font.pixelSize: 13
        selectByMouse: true
        clip: true
        validator: fld.numeric ? intV : null
        inputMethodHints: fld.numeric ? Qt.ImhDigitsOnly : Qt.ImhNone

        KeyNavigation.tab: fld.tabTarget

        onAccepted: fld.submitted()

        Label {
          visible: ti.text === ""
          anchors.verticalCenter: parent.verticalCenter
          text: fld.placeholder
          color: sw.cMuted
          font.pixelSize: 12
        }
      }
    }
  }

  // bloco com o comando ssh montado
  component CmdBlock: Rectangle {
    property string cmd: ""
    property color tint: sw.cAccent

    Layout.fillWidth: true
    implicitHeight: cmdLabel.implicitHeight + 22
    radius: 14
    color: sw.cTerm

    Label {
      id: cmdLabel

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      text: "$ " + parent.cmd
      color: parent.tint
      font.pixelSize: 11
      wrapMode: Text.WrapAnywhere
      elide: Text.ElideNone
    }
  }

  // Local / Destino / Gateway
  component SummaryCard: Rectangle {
    Layout.fillWidth: true
    implicitHeight: sumCol.implicitHeight + 28
    radius: 16
    color: sw.cItem

    Column {
      id: sumCol

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      spacing: 8

      Repeater {
        model: [
          { k: "Local", v: "localhost:" + sw.tLocal },
          { k: "Destino", v: sw.tIp + ":" + sw.tDest },
          { k: "Gateway", v: sw.sshTarget }
        ]

        delegate: RowLayout {
          required property var modelData

          width: sumCol.width
          spacing: 8

          Label {
            text: modelData.k
            color: sw.cMuted
            font.pixelSize: 11
            Layout.preferredWidth: 70
          }

          Label {
            text: modelData.v
            font.bold: true
            Layout.fillWidth: true
          }
        }
      }
    }
  }

  // ================================================================
  // JANELA
  // ================================================================

  Item {
    id: rootItem

    anchors.fill: parent
    focus: true

    Keys.onEscapePressed: sw.closeRequested()

    // clique fora do cartão fecha (só no modo desafixado)
    MouseArea {
      anchors.fill: parent
      enabled: !sw.passthrough
      onClicked: sw.closeRequested()
    }

    Rectangle {
      id: card

      width: sw.panelWidth
      x: sw.leftPad + 8 - (1 - sw.slide) * 36
      y: sw.atBottom ? 8 : sw.topInset
      opacity: sw.slide
      height: parent.height - y - (sw.atBottom ? sw.bottomInset : 8)

      radius: Math.min(sw.moduleRadius, 28)
      color: sw.cBg
      border.width: 1
      border.color: sw.cLine
      clip: true

      // engole cliques dentro do cartão
      MouseArea {
        anchors.fill: parent
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ---------- cabeçalho ----------
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Glyph {
            text: "\uf120" // terminal
            color: sw.cAccent
            font.pixelSize: 20
          }

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 32
            radius: height / 2
            color: sw.cItem

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 14
              anchors.rightMargin: 12
              spacing: 8

              Label {
                text: sw.headerTitle
                font.bold: true
                Layout.fillWidth: true
              }

              Glyph {
                text: "\uf111" // circle: estado do túnel
                font.pixelSize: 9
                color: (sw.stage === "ready" || sw.stage === "browser")
                  ? sw.cAccent
                  : (sw.stage === "tunnel" ? sw.cMuted : sw.cLine)
              }
            }
          }

          RoundBtn {
            visible: sw.stage === "ready" || sw.stage === "browser"
            glyph: "\uf011" // power-off: encerra sessão + túnel
            onClicked: sw.closeAll()
          }

          RoundBtn {
            glyph: "\uf08d" // thumb-tack: fixar
            active: sw.pinned
            onClicked: sw.pinned = !sw.pinned
          }

          RoundBtn {
            glyph: "\uf00d" // times: fechar
            onClicked: sw.closeRequested()
          }
        }

        // ---------- aviso / erro ----------
        Rectangle {
          visible: sw.banner !== ""
          Layout.fillWidth: true
          implicitHeight: bannerRow.implicitHeight + 16
          radius: 14
          color: sw.cItem
          border.width: 1
          border.color: sw.cError

          RowLayout {
            id: bannerRow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 8

            Label {
              text: sw.banner
              color: sw.cError
              font.pixelSize: 11
              wrapMode: Text.Wrap
              elide: Text.ElideNone
              Layout.fillWidth: true
            }

            RoundBtn {
              glyph: "\uf00d"
              implicitWidth: 28
              implicitHeight: 28

              onClicked: {
                sw.formError = "";
                sw.notice = "";
                sw.tunnelWarn = "";
              }
            }
          }
        }

        // ---------- corpo (uma tela por etapa) ----------
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          // ===== 1. formulário =====
          ColumnLayout {
            visible: sw.stage === "form"
            anchors.fill: parent
            spacing: 8

            Label {
              text: "Configuração do túnel"
              font.bold: true
              font.pixelSize: 14
              Layout.bottomMargin: 4
            }

            Field {
              id: fLocal

              label: "Porta local"
              placeholder: "2222"
              numeric: true
              text: "2222"
              tabTarget: fIp.input
              onSubmitted: fIp.input.forceActiveFocus()
            }

            Field {
              id: fIp

              label: "IP do destino"
              placeholder: "192.168.0.10"
              tabTarget: fDest.input
              onSubmitted: fDest.input.forceActiveFocus()
            }

            Field {
              id: fDest

              label: "Porta do destino"
              placeholder: "22"
              numeric: true
              text: "22"
              tabTarget: fUser.input
              onSubmitted: fUser.input.forceActiveFocus()
            }

            Field {
              id: fUser

              label: "Usuário SSH"
              placeholder: "pi"
              tabTarget: fHost.input
              onSubmitted: fHost.input.forceActiveFocus()
            }

            Field {
              id: fHost

              label: "Host SSH/Gateway"
              placeholder: "gateway.exemplo.com"
              tabTarget: fLocal.input
              onSubmitted: sw.startTunnel()
            }

            CmdBlock {
              Layout.topMargin: 6
              tint: sw.cMuted
              cmd: "ssh -N -L " + (fLocal.text || "porta") + ":" + (fIp.text || "ip") + ":"
                + (fDest.text || "porta") + " " + (fUser.text || "usuário") + "@" + (fHost.text || "gateway")
            }

            Item {
              Layout.fillHeight: true
            }

            PillBtn {
              Layout.fillWidth: true
              primary: true
              glyph: "\uf0c1" // link
              text: "Abrir túnel"
              onClicked: sw.startTunnel()
            }
          }

          // ===== 2. abrindo o túnel =====
          ColumnLayout {
            visible: sw.stage === "tunnel"
            anchors.fill: parent
            spacing: 12

            RowLayout {
              spacing: 10

              Spinner {
                font.pixelSize: 18
              }

              Label {
                text: "Abrindo o túnel…"
                font.bold: true
                font.pixelSize: 14
              }
            }

            SummaryCard {
            }

            CmdBlock {
              cmd: sw.tunnelCmd
            }

            Label {
              Layout.fillWidth: true
              text: "Se o ssh pedir senha ou passphrase, uma janela do zenity aparece por cima do painel. "
                + "Depois a porta local é testada até o destino responder como SSH."
              color: sw.cMuted
              font.pixelSize: 11
              wrapMode: Text.Wrap
              elide: Text.ElideNone
            }

            Item {
              Layout.fillHeight: true
            }

            PillBtn {
              Layout.fillWidth: true
              glyph: "\uf00d"
              text: "Cancelar"
              onClicked: sw.closeAll()
            }
          }

          // ===== 3. túnel pronto: conectar? =====
          ColumnLayout {
            visible: sw.stage === "ready"
            anchors.fill: parent
            spacing: 12

            RowLayout {
              spacing: 10

              Glyph {
                text: "\uf00c" // check
                color: sw.cAccent
                font.pixelSize: 18
              }

              Label {
                text: "Túnel ativo"
                font.bold: true
                font.pixelSize: 14
              }
            }

            SummaryCard {
            }

            CmdBlock {
              cmd: sw.tunnelCmd
            }

            Label {
              Layout.fillWidth: true
              Layout.topMargin: 6
              text: "Conectar via SSH em " + sw.tUser + "@" + sw.tIp + "?"
              font.bold: true
              wrapMode: Text.Wrap
              elide: Text.ElideNone
            }

            Label {
              Layout.fillWidth: true
              text: "Abre `ssh -p " + sw.tLocal + " " + sw.tUser + "@localhost` com o navegador de pastas e um mini terminal."
              color: sw.cMuted
              font.pixelSize: 11
              wrapMode: Text.Wrap
              elide: Text.ElideNone
            }

            Item {
              Layout.fillHeight: true
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              PillBtn {
                Layout.fillWidth: true
                primary: true
                glyph: "\uf120"
                text: "Conectar"
                onClicked: sw.connectShell()
              }

              PillBtn {
                glyph: "\uf127" // chain-broken
                text: "Encerrar túnel"
                onClicked: sw.closeAll()
              }
            }
          }

          // ===== 4. conectando =====
          ColumnLayout {
            visible: sw.stage === "browser" && !sw.shellUp
            anchors.fill: parent
            spacing: 12

            Item {
              Layout.fillHeight: true
            }

            Spinner {
              Layout.alignment: Qt.AlignHCenter
              font.pixelSize: 26
            }

            Label {
              Layout.fillWidth: true
              text: "Autenticando em " + sw.sshTarget.replace(/@.*/, "") + "@" + sw.tIp + "…"
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }

            Label {
              Layout.fillWidth: true
              text: "Se pedir senha, a janela do zenity aparece por cima."
              color: sw.cMuted
              font.pixelSize: 11
              horizontalAlignment: Text.AlignHCenter
            }

            Item {
              Layout.fillHeight: true
            }

            PillBtn {
              Layout.fillWidth: true
              glyph: "\uf00d"
              text: "Cancelar"
              onClicked: sw.disconnectShell()
            }
          }

          // ===== 5. pastas + mini terminal =====
          ColumnLayout {
            visible: sw.stage === "browser" && sw.shellUp
            anchors.fill: parent
            spacing: 8

            // barra de caminho
            RowLayout {
              Layout.fillWidth: true
              spacing: 6

              RoundBtn {
                glyph: "\uf062" // arrow-up
                onClicked: sw.shellRun("cd ..", false)
              }

              Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: 16
                color: sw.cItem

                Label {
                  anchors.fill: parent
                  anchors.leftMargin: 14
                  anchors.rightMargin: 14
                  text: sw.cwdShort
                  elide: Text.ElideLeft
                  font.pixelSize: 12
                }
              }

              RoundBtn {
                glyph: "\uf021" // refresh
                onClicked: sw.refreshList()
              }

              RoundBtn {
                glyph: "\uf06e" // eye: mostrar ocultos
                active: sw.showHidden

                onClicked: {
                  sw.showHidden = !sw.showHidden;
                  sw.refreshList();
                }
              }

              RoundBtn {
                glyph: "\uf08b" // sign-out: fecha a sessão, mantém o túnel
                onClicked: sw.disconnectShell()
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              PillBtn {
                Layout.fillWidth: true
                primary: true
                glyph: sw.uploadBusy ? "\uf110" : "\uf093"
                text: sw.uploadBusy ? "Enviando…" : "Enviar arquivos"
                onClicked: sw.chooseUploads()
              }

              PillBtn {
                Layout.fillWidth: true
                primary: sw.selectedCount() > 0 && !sw.downloadBusy
                glyph: sw.downloadBusy ? "\uf110" : "\uf019"
                text: sw.downloadBusy
                  ? "Baixando…"
                  : "Baixar (" + sw.selectedCount() + ")"
                onClicked: sw.downloadSelected()
              }

              RoundBtn {
                glyph: "\uf12d"
                onClicked: sw.clearFileSelection()
              }
            }

            Label {
              visible: sw.uploadStatus !== ""
              Layout.fillWidth: true
              text: sw.uploadStatus
              color: sw.uploadStatus.indexOf("Falha") === 0 ? sw.cError : sw.cMuted
              font.pixelSize: 10
              wrapMode: Text.Wrap
              elide: Text.ElideNone
            }

            Label {
              visible: sw.downloadStatus !== ""
              Layout.fillWidth: true
              text: sw.downloadStatus
              color: sw.downloadStatus.indexOf("Falha") === 0 ? sw.cError : sw.cMuted
              font.pixelSize: 10
              wrapMode: Text.Wrap
              elide: Text.ElideNone
            }

            Item {
              id: split

              Layout.fillWidth: true
              Layout.fillHeight: true

              // ---------- pastas ----------
              Rectangle {
                id: filesBox

                x: 0
                y: 0
                width: split.width
                height: Math.round(split.height * sw.splitFrac) - 6
                radius: 16
                color: sw.cItem
                clip: true

                ListView {
                  id: fileView

                  anchors.fill: parent
                  anchors.margins: 6
                  model: fileModel
                  clip: true
                  spacing: 2
                  boundsBehavior: Flickable.StopAtBounds

                  delegate: Rectangle {
                    id: row

                    required property string fname
                    required property bool isDir
                    required property bool selected

                    width: fileView.width
                    height: 30
                    radius: 12
                    color: row.selected ? sw.cAccent : (rowArea.containsMouse ? sw.cItemHi : "transparent")

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: 10
                      anchors.rightMargin: 10
                      spacing: 10

                      Glyph {
                        text: row.fname === ".." ? "\uf148" : (row.isDir ? "\uf07b" : (row.selected ? "\uf046" : "\uf15b")) // level-up / folder / file / selected
                        color: row.selected ? sw.cOnAccent : (row.isDir ? sw.cAccent : sw.cMuted)
                        font.pixelSize: 13
                        Layout.preferredWidth: 16
                      }

                      Label {
                        text: row.fname
                        font.bold: row.isDir || row.selected
                        color: row.selected ? sw.cOnAccent : sw.cText
                        Layout.fillWidth: true
                      }
                    }

                    MouseArea {
                      id: rowArea

                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: sw.openEntry(row.fname, row.isDir)
                    }
                  }

                  Label {
                    visible: fileModel.count <= 1 && sw.listError === "" && !lsProc.running
                    anchors.centerIn: parent
                    text: "pasta vazia"
                    color: sw.cMuted
                  }

                  Label {
                    visible: sw.listError !== ""
                    anchors.centerIn: parent
                    text: sw.listError
                    color: sw.cError
                  }

                  Rectangle {
                    visible: fileView.contentHeight > fileView.height
                    x: parent.width - 4
                    y: fileView.visibleArea.yPosition * fileView.height
                    width: 3
                    height: Math.max(24, fileView.visibleArea.heightRatio * fileView.height)
                    radius: 2
                    color: sw.cMuted
                    opacity: 0.5
                  }
                }
              }

              // ---------- alça pra redimensionar ----------
              Item {
                id: grip

                x: 0
                y: filesBox.height
                width: split.width
                height: 12

                Rectangle {
                  anchors.centerIn: parent
                  width: 40
                  height: 4
                  radius: 2
                  color: (gripArea.pressed || gripArea.containsMouse) ? sw.cAccent : sw.cLine
                }

                MouseArea {
                  id: gripArea

                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.SplitVCursor

                  onPositionChanged: (mouse) => {
                    if (!gripArea.pressed) {
                      return;
                    }

                    const p = gripArea.mapToItem(split, mouse.x, mouse.y).y;

                    sw.splitFrac = Math.max(0.25, Math.min(0.75, p / split.height));
                  }
                }
              }

              // ---------- mini terminal ----------
              Rectangle {
                id: termBox

                x: 0
                y: filesBox.height + 12
                width: split.width
                height: split.height - y
                radius: 16
                color: sw.cTerm
                border.width: 1
                border.color: sw.cLine
                clip: true

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 8
                  spacing: 6

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Glyph {
                      text: "\uf120"
                      color: sw.cMuted
                      font.pixelSize: 11
                    }

                    Label {
                      text: "terminal"
                      color: sw.cMuted
                      font.pixelSize: 11
                      Layout.fillWidth: true
                    }

                    RoundBtn {
                      glyph: "\uf1f8" // trash: limpa a saída
                      implicitWidth: 22
                      implicitHeight: 22
                      onClicked: termModel.clear()
                    }
                  }

                  ListView {
                    id: termView

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: termModel
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    onCountChanged: {
                      if (sw.stickTerm) {
                        Qt.callLater(() => termView.positionViewAtEnd());
                      }
                    }

                    onMovementEnded: sw.stickTerm = termView.atYEnd

                    delegate: Text {
                      required property string kind
                      required property string txt

                      width: termView.width
                      text: txt === "" ? " " : txt
                      textFormat: Text.PlainText
                      wrapMode: Text.WrapAnywhere
                      font.family: sw.nerdFont
                      font.pixelSize: 11
                      color: kind === "cmd" ? sw.cAccent
                        : (kind === "err" ? sw.cError
                          : (kind === "sys" ? sw.cMuted : sw.cBody))
                    }
                  }

                  // entrada
                  Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: 16
                    color: sw.cItem

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: 12
                      anchors.rightMargin: 12
                      spacing: 6

                      Label {
                        text: sw.tUser + "@" + sw.tIp + ":" + sw.cwdShort + "$"
                        color: sw.cAccent
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: 170
                      }

                      Spinner {
                        visible: sw.busyCmds > 0
                        font.pixelSize: 11
                      }

                      TextInput {
                        id: termInput

                        Layout.fillWidth: true
                        color: sw.cText
                        selectionColor: sw.cAccent
                        selectedTextColor: sw.cOnAccent
                        font.family: sw.nerdFont
                        font.pixelSize: 12
                        selectByMouse: true
                        clip: true

                        onAccepted: sw.submitCmd()

                        Keys.onUpPressed: {
                          if (sw.hist.length === 0) {
                            return;
                          }

                          sw.histPos = sw.histPos < 0 ? sw.hist.length - 1 : Math.max(0, sw.histPos - 1);
                          termInput.text = sw.hist[sw.histPos];
                          termInput.cursorPosition = termInput.text.length;
                        }

                        Keys.onDownPressed: {
                          if (sw.histPos < 0) {
                            return;
                          }

                          sw.histPos++;

                          if (sw.histPos >= sw.hist.length) {
                            sw.histPos = -1;
                            termInput.text = "";
                          } else {
                            termInput.text = sw.hist[sw.histPos];
                            termInput.cursorPosition = termInput.text.length;
                          }
                        }

                        Label {
                          visible: termInput.text === ""
                          anchors.verticalCenter: parent.verticalCenter
                          text: "comando…"
                          color: sw.cMuted
                          font.pixelSize: 11
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
