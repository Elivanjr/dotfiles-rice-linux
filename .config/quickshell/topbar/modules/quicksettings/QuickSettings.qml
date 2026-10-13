// QuickSettings.qml — painel de Wi-Fi + Bluetooth estilo "quick settings" do GNOME
//
// Páginas dentro do mesmo cartão:
//   principal: botões grandes (Wi-Fi, Bluetooth e Modo de energia). Clicar no
//              corpo liga/desliga (no modo de energia, alterna o perfil);
//              clicar no ">" abre a página de detalhes.
//   wifi / bt: lista de redes / dispositivos, com chave liga/desliga no topo e
//              botão de voltar. Escape também volta.
//   power:     escolha do perfil do power-profiles-daemon (via powerprofilesctl).
//
// Na página principal ficam também: sliders de volume/microfone (com mute) e os
// anéis de CPU, RAM e Disco (uso, total e livre). As leituras só rodam com o
// painel aberto na página principal.
//
// Também na principal: card de mídia (MPRIS) com capa, título, barra de progresso
// com seek e controles. Pega qualquer player MPRIS (Spotify, mpv, VLC, Kopuz,
// navegadores Chromium como Brave/Chrome/Opera/Vivaldi...). Com mais de um player
// ativo, as setinhas do card alternam entre eles.
//
// O botão "Estilo escuro" alterna claro/escuro chamando o tema.sh (matugen +
// GTK + Hyprland). O script fica em scripts/theme/tema.sh.
//
// Abre sob a topbar (canto direito) ou, no modo Windows 10, acima da WinBar.
// Controlado de fora por panelOpen / closeRequested(), igual aos outros painéis.
// Clicar fora do cartão fecha (a janela é uma camada transparente de tela cheia).
//
// Cores: Colors.qml (matugen).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "../../theme"

PanelWindow {
  id: qs

  required property var screenRef
  screen: screenRef

  property bool panelOpen: false
  property bool atBottom: false     // true no modo Windows 10
  property int topInset: 51         // altura da topbar
  property int bottomInset: 46      // altura da WinBar + folga
  property string nerdFont: "JetBrainsMono NF"
  property int moduleRadius: 20     // vem do shell.qml (root.moduleRadius)

  signal closeRequested()

  visible: panelOpen
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.namespace: "quickshell:quicksettings"

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

  // ================================================================
  // ESTADO
  // ================================================================

  property string page: "main"      // "main" | "wifi" | "bt"
  property var pwNetwork: null      // rede esperando senha
  property var wifiRows: []
  property var btRows: []

  // ---------- Wi-Fi ----------
  readonly property var wifiDevice: {
    for (const d of Networking.devices.values) {
      if (d.type === DeviceType.Wifi) {
        return d;
      }
    }

    return null;
  }

  readonly property var activeWifi: {
    const dev = qs.wifiDevice;

    if (!dev) {
      return null;
    }

    for (const n of dev.networks.values) {
      if (n.connected) {
        return n;
      }
    }

    return null;
  }

  // ---------- Bluetooth ----------
  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property bool btOn: btAdapter ? btAdapter.enabled : false

  readonly property var btFirstConnected: {
    for (const d of Bluetooth.devices.values) {
      if (d.connected) {
        return d;
      }
    }

    return null;
  }

  // ---------- Modo de energia (power-profiles-daemon) ----------
  property string ppActive: ""          // "performance" | "balanced" | "power-saver"
  property var ppAvail: []              // perfis que o hardware oferece
  property string ppPerfNote: ""        // motivo de "Degraded", se houver

  readonly property var batt: UPower.displayDevice

  readonly property string batteryText: {
    const b = qs.batt;

    if (!b) {
      return "";
    }

    const charging = b.state === UPowerDeviceState.Charging;

    return (charging ? "\u{F0084} " : "\u{F0079} ") + Math.round(b.percentage * 100) + "%";
  }

  // ================================================================
  // FUNÇÕES
  // ================================================================

  // ---------- Estilo escuro/claro (tema.sh) ----------
  property string themeScript: Quickshell.env("HOME") + "/.config/quickshell/topbar/scripts/theme/tema.sh"
  property bool themeBusy: false
  property bool themeFailed: false

  // claro ou escuro? lê a luminância do surface que o matugen gerou
  readonly property bool isDark: {
    const c = Qt.color(Colors.md3.surface);

    return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) < 0.5;
  }

  function toggleTheme() {
    if (themeProc.running) {
      return;
    }

    qs.themeFailed = false;
    qs.themeBusy = true;
    themeProc.command = ["bash", qs.themeScript, qs.isDark ? "light" : "dark"];
    themeProc.running = true;
  }

  function ppName(key) {
    if (key === "performance") return "Desempenho";
    if (key === "balanced") return "Equilibrado";
    if (key === "power-saver") return "Economia";

    return "Indisponível";
  }

  function ppGlyph(key) {
    if (key === "performance") return "\u{F04C5}"; // md-speedometer
    if (key === "power-saver") return "\u{F032A}"; // md-leaf

    return "\u{F05D1}"; // md-scale-balance
  }

  // lê a saída de `powerprofilesctl list`:
  //   "* balanced:" = perfil ativo, "  performance:" = disponível
  //   "    Degraded:   yes (lap-detected)" dentro do bloco do performance
  function parseProfiles(text) {
    const avail = [];
    let active = "";
    let note = "";
    let cur = "";

    for (const raw of text.split("\n")) {
      const m = raw.match(/^([* ])\s*([a-z-]+):\s*$/);

      if (m) {
        cur = m[2];
        avail.push(cur);

        if (m[1] === "*") {
          active = cur;
        }

        continue;
      }

      const d = raw.match(/^\s*Degraded:\s+yes(?:\s*\(([^)]*)\))?/);

      if (d && cur === "performance") {
        const why = d[1] || "";

        note = why === "lap-detected" ? "reduzido (notebook no colo)"
          : why === "high-operating-temperature" ? "reduzido (temperatura alta)"
          : "reduzido";
      }
    }

    qs.ppAvail = avail;
    qs.ppActive = active;
    qs.ppPerfNote = note;
  }

  function refreshProfiles() {
    if (!ppList.running && !ppSet.running) {
      ppList.running = true;
    }
  }

  function setProfile(key) {
    if (ppSet.running || qs.ppAvail.indexOf(key) === -1) {
      return;
    }

    ppSet.command = ["powerprofilesctl", "set", key];
    ppSet.running = true;
    qs.ppActive = key; // otimista; o refresh depois confirma
  }

  // clique no corpo do botão: economia -> equilibrado -> desempenho -> ...
  function cycleProfile() {
    const order = ["power-saver", "balanced", "performance"].filter(
      k => qs.ppAvail.indexOf(k) !== -1
    );

    if (order.length === 0) {
      return;
    }

    const i = order.indexOf(qs.ppActive);

    qs.setProfile(order[(i + 1) % order.length]);
  }

  // sinal e bateria podem vir em 0..1 ou 0..100 — normaliza pra 0..1
  function norm(v) {
    const x = Number(v);

    if (isNaN(x)) {
      return 0;
    }

    return x > 1 ? x / 100 : x;
  }

  function sameList(a, b) {
    if (a.length !== b.length) {
      return false;
    }

    for (let i = 0; i < a.length; i++) {
      if (a[i] !== b[i]) {
        return false;
      }
    }

    return true;
  }

  // A lista só é remontada quando a ORDEM muda. Se mudasse a cada variação de
  // sinal, a linha onde você está digitando a senha seria recriada.
  function refreshWifi() {
    if (qs.pwNetwork) {
      return;
    }

    const dev = qs.wifiDevice;
    let arr = [];

    if (dev) {
      arr = Array.from(dev.networks.values).filter(n => n.name && n.name.length > 0);

      arr.sort((a, b) =>
        (b.connected - a.connected) ||
        (qs.norm(b.signalStrength) - qs.norm(a.signalStrength))
      );
    }

    if (!qs.sameList(arr, qs.wifiRows)) {
      qs.wifiRows = arr;
    }
  }

  function refreshBt() {
    const macLike = /^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i;

    const arr = Array.from(Bluetooth.devices.values).filter(
      d => d.paired || (d.name && !macLike.test(d.name))
    );

    arr.sort((a, b) =>
      (b.connected - a.connected) ||
      (b.paired - a.paired) ||
      String(a.name).localeCompare(String(b.name))
    );

    if (!qs.sameList(arr, qs.btRows)) {
      qs.btRows = arr;
    }
  }

  // só escaneia enquanto a página correspondente está aberta
  function syncScan() {
    const dev = qs.wifiDevice;

    if (dev) {
      const wantWifi = qs.panelOpen && qs.page === "wifi" && Networking.wifiEnabled;

      if (dev.scannerEnabled !== wantWifi) {
        dev.scannerEnabled = wantWifi;
      }
    }

    const a = Bluetooth.defaultAdapter;

    if (a) {
      const wantBt = qs.panelOpen && qs.page === "bt" && a.enabled;

      if (a.discovering !== wantBt) {
        a.discovering = wantBt;
      }
    }
  }

  function back() {
    if (qs.pwNetwork) {
      qs.pwNetwork = null;
    } else if (qs.page !== "main") {
      qs.page = "main";
    } else {
      qs.closeRequested();
    }
  }

  function toggleBluetooth() {
    const a = Bluetooth.defaultAdapter;

    if (!a) {
      return;
    }

    if (a.enabled) {
      a.enabled = false;
    } else {
      // adaptador com rfkill "soft blocked" não liga sem desbloquear antes
      rfkillProc.running = true;
    }
  }

  function btGlyph(icon) {
    const i = (icon || "").toLowerCase();

    if (i.indexOf("headset") !== -1 || i.indexOf("headphone") !== -1) return "\u{F02CB}";
    if (i.indexOf("keyboard") !== -1) return "\u{F030C}";
    if (i.indexOf("mouse") !== -1) return "\u{F037D}";
    if (i.indexOf("gaming") !== -1 || i.indexOf("joystick") !== -1) return "\u{F0297}";
    if (i.indexOf("phone") !== -1) return "\u{F011C}";
    if (i.indexOf("computer") !== -1 || i.indexOf("laptop") !== -1) return "\u{F0322}";
    if (i.indexOf("audio") !== -1 || i.indexOf("speaker") !== -1) return "\u{F04C3}";

    return "\u{F00AF}";
  }

  onPageChanged: {
    qs.pwNetwork = null;
    qs.syncScan();
  }

  onPanelOpenChanged: {
    if (qs.panelOpen) {
      rootItem.forceActiveFocus();
      qs.statPrevTotal = -1; // evita um primeiro valor de CPU "médio" do tempo em que ficou fechado
    } else {
      qs.page = "main";
      qs.pwNetwork = null;
      qs.mprisPick = "";
    }

    qs.syncScan();
  }

  Connections {
    target: Networking

    function onWifiEnabledChanged() {
      qs.syncScan();
    }
  }

  Connections {
    target: Bluetooth.defaultAdapter

    function onEnabledChanged() {
      qs.syncScan();
    }
  }

  Process {
    id: rfkillProc

    command: ["rfkill", "unblock", "bluetooth"]

    onExited: {
      const a = Bluetooth.defaultAdapter;

      if (a) {
        a.enabled = true;
      }
    }
  }

  Process {
    id: themeProc

    command: ["bash", qs.themeScript, "status"]

    onExited: (exitCode, exitStatus) => {
      qs.themeBusy = false;
      qs.themeFailed = exitCode !== 0;
    }
  }

  Process {
    id: ppList

    command: ["powerprofilesctl", "list"]

    stdout: StdioCollector {
      onStreamFinished: qs.parseProfiles(this.text)
    }
  }

  Process {
    id: ppSet

    command: ["powerprofilesctl", "set", "balanced"]

    onExited: qs.refreshProfiles()
  }

  // enquanto o painel está aberto, acompanha mudanças feitas por fora
  // (ex.: `powerprofilesctl set ...` no terminal)
  Timer {
    interval: 3000
    running: qs.panelOpen
    repeat: true
    triggeredOnStart: true
    onTriggered: qs.refreshProfiles()
  }

  Timer {
    interval: 2500
    running: qs.panelOpen && qs.page === "wifi"
    repeat: true
    triggeredOnStart: true
    onTriggered: qs.refreshWifi()
  }

  Timer {
    interval: 2000
    running: qs.panelOpen && qs.page === "bt"
    repeat: true
    triggeredOnStart: true
    onTriggered: qs.refreshBt()
  }

  // ---------- CPU / RAM / Disco ----------
  property real cpuUsage: 0          // 0..1
  property real ramUsedGb: 0
  property real ramTotalGb: 0
  property real diskTotalGb: 0
  property real diskFreeGb: 0
  property real statPrevIdle: -1
  property real statPrevTotal: -1

  readonly property real ramFrac: qs.ramTotalGb > 0 ? qs.ramUsedGb / qs.ramTotalGb : 0
  readonly property real diskUsedFrac: qs.diskTotalGb > 0 ? 1 - qs.diskFreeGb / qs.diskTotalGb : 0

  function fmtGb(v) {
    if (v >= 1000) {
      return (v / 1024).toFixed(1) + " TB";
    }

    if (v >= 100) {
      return Math.round(v) + " GB";
    }

    return v.toFixed(1) + " GB";
  }

  function spkGlyph(muted, v) {
    if (muted || v <= 0) return "\u{F0581}"; // volume_off
    if (v <= 0.25) return "\u{F0580}";       // volume_low
    if (v <= 0.5) return "\u{F057F}";        // volume_medium

    return "\u{F057E}";                      // volume_high
  }

  // /proc/stat (primeira linha) + /proc/meminfo, lidos juntos
  function parseStats(text) {
    const parts = text.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
    const idle = parts[3] + parts[4];
    const total = parts.reduce((a, b) => a + b, 0);

    if (qs.statPrevTotal >= 0) {
      const dTotal = total - qs.statPrevTotal;
      const dIdle = idle - qs.statPrevIdle;

      qs.cpuUsage = dTotal > 0 ? Math.max(0, Math.min(1, 1 - dIdle / dTotal)) : 0;
    }

    qs.statPrevIdle = idle;
    qs.statPrevTotal = total;

    const mt = /MemTotal:\s+(\d+)/.exec(text);
    const ma = /MemAvailable:\s+(\d+)/.exec(text);

    if (mt && ma) {
      const tot = parseInt(mt[1]);
      const avail = parseInt(ma[1]);

      qs.ramTotalGb = tot / 1048576;
      qs.ramUsedGb = (tot - avail) / 1048576;
    }
  }

  // saída de `df -B1 --output=size,avail /`
  function parseDisk(text) {
    const rows = text.trim().split("\n");

    if (rows.length < 2) {
      return;
    }

    const f = rows[1].trim().split(/\s+/).map(Number);

    if (f.length < 2 || isNaN(f[0]) || f[0] <= 0) {
      return;
    }

    qs.diskTotalGb = f[0] / 1073741824;
    qs.diskFreeGb = f[1] / 1073741824;
  }

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
  }

  Process {
    id: statProc

    command: ["cat", "/proc/stat", "/proc/meminfo"]

    stdout: StdioCollector {
      onStreamFinished: qs.parseStats(this.text)
    }
  }

  Process {
    id: diskProc

    command: ["df", "-B1", "--output=size,avail", "/"]

    stdout: StdioCollector {
      onStreamFinished: qs.parseDisk(this.text)
    }
  }

  Timer {
    interval: 1500
    running: qs.panelOpen && qs.page === "main"
    repeat: true
    triggeredOnStart: true

    onTriggered: {
      if (!statProc.running) {
        statProc.running = true;
      }
    }
  }

  Timer {
    interval: 15000
    running: qs.panelOpen && qs.page === "main"
    repeat: true
    triggeredOnStart: true

    onTriggered: {
      if (!diskProc.running) {
        diskProc.running = true;
      }
    }
  }

  // ---------- MPRIS (Spotify, mpv, VLC, Kopuz, navegadores Chromium...) ----------
  // Entram todos os players que têm faixa ou estão tocando. Quem aparece no card:
  // o que você escolheu nas setinhas; senão o primeiro que estiver tocando.
  property string mprisPick: ""

  function pkey(p) {
    return (p.dbusName || "") + "|" + (p.identity || "");
  }

  readonly property var mprisList: {
    const out = [];

    for (const p of Mpris.players.values) {
      if ((p.trackTitle || "") !== "" || p.isPlaying) {
        out.push(p);
      }
    }

    return out;
  }

  readonly property var mprisPlayer: {
    const l = qs.mprisList;

    if (l.length === 0) {
      return null;
    }

    for (const p of l) {
      if (qs.pkey(p) === qs.mprisPick) {
        return p;
      }
    }

    for (const p of l) {
      if (p.isPlaying) {
        return p;
      }
    }

    return l[0];
  }

  readonly property int mprisIndex: qs.mprisList.indexOf(qs.mprisPlayer)

  readonly property real mprisPos:
    (qs.mprisPlayer && qs.mprisPlayer.positionSupported) ? qs.mprisPlayer.position : 0

  readonly property real mprisLen:
    (qs.mprisPlayer && qs.mprisPlayer.lengthSupported) ? qs.mprisPlayer.length : 0

  function mprisCycle(d) {
    const l = qs.mprisList;

    if (l.length < 2) {
      return;
    }

    const i = (Math.max(0, l.indexOf(qs.mprisPlayer)) + d + l.length) % l.length;

    qs.mprisPick = qs.pkey(l[i]);
  }

  function fmtTime(s) {
    if (!isFinite(s) || s < 0) {
      return "0:00";
    }

    const t = Math.floor(s);
    const h = Math.floor(t / 3600);
    const m = Math.floor((t % 3600) / 60);
    const sec = t % 60;
    const ss = (sec < 10 ? "0" : "") + sec;

    if (h > 0) {
      return h + ":" + (m < 10 ? "0" : "") + m + ":" + ss;
    }

    return m + ":" + ss;
  }

  // a posição do MPRIS não se atualiza sozinha: precisa "cutucar" enquanto toca
  Timer {
    interval: 500
    running: qs.panelOpen && qs.page === "main" && qs.mprisPlayer !== null && qs.mprisPlayer.isPlaying
    repeat: true

    onTriggered: {
      if (qs.mprisPlayer) {
        qs.mprisPlayer.positionChanged();
      }
    }
  }

  // ================================================================
  // COMPONENTES
  // ================================================================

  component Glyph: Text {
    font.family: qs.nerdFont
    font.pixelSize: 16
    color: qs.cText
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  component Label: Text {
    font.family: qs.nerdFont
    font.pixelSize: 12
    color: qs.cText
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
  }

  component Toggle: Rectangle {
    id: tg

    property bool checked: false

    signal toggled()

    implicitWidth: 44
    implicitHeight: 24
    radius: 12
    color: tg.checked ? qs.cAccent : qs.cItemHi

    Behavior on color {
      ColorAnimation {
        duration: 120
      }
    }

    Rectangle {
      y: 3
      x: tg.checked ? parent.width - width - 3 : 3
      width: 18
      height: 18
      radius: 9
      color: tg.checked ? qs.cOnAccent : qs.cMuted

      Behavior on x {
        NumberAnimation {
          duration: 120
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: tg.toggled()
    }
  }

  component RoundBtn: Rectangle {
    id: rb

    property string glyph: ""

    signal clicked()

    implicitWidth: 32
    implicitHeight: 32
    radius: 16
    color: rbArea.containsMouse ? qs.cItemHi : qs.cItem

    Glyph {
      anchors.centerIn: parent
      text: rb.glyph
      font.pixelSize: 13
    }

    MouseArea {
      id: rbArea

      anchors.fill: parent
      hoverEnabled: true
      onClicked: rb.clicked()
    }
  }

  // botão grande da página principal: corpo liga/desliga, ">" abre detalhes
  component QuickToggle: Rectangle {
    id: tgl

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool available: true
    property bool showChevron: true   // false = botão simples, sem ">"

    signal toggled()
    signal expand()

    readonly property color fg: tgl.active ? qs.cOnAccent : qs.cText

    Layout.fillWidth: true
    implicitHeight: 56
    radius: Math.min(qs.moduleRadius, height / 2)
    color: tgl.active ? qs.cAccent : qs.cItem
    opacity: tgl.available ? 1 : 0.5

    Behavior on color {
      ColorAnimation {
        duration: 140
      }
    }

    Item {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: tgl.showChevron ? chevArea.left : parent.right

      Rectangle {
        anchors.fill: parent
        radius: Math.min(qs.moduleRadius, height / 2)
        color: Qt.alpha(tgl.fg, mainMouse.containsMouse ? 0.08 : 0)
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 4
        spacing: 10

        Glyph {
          text: tgl.icon
          color: tgl.fg
          font.pixelSize: 19
          Layout.preferredWidth: 22
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          Label {
            text: tgl.title
            color: tgl.fg
            font.bold: true
            font.pixelSize: 13
            Layout.fillWidth: true
          }

          Label {
            text: tgl.subtitle
            color: tgl.fg
            opacity: 0.75
            font.pixelSize: 10
            Layout.fillWidth: true
          }
        }
      }

      MouseArea {
        id: mainMouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: tgl.available
        onClicked: tgl.toggled()
      }
    }

    Rectangle {
      visible: tgl.showChevron
      anchors.right: chevArea.left
      anchors.verticalCenter: parent.verticalCenter
      width: 1
      height: 28
      color: Qt.alpha(tgl.fg, 0.3)
    }

    Item {
      id: chevArea

      visible: tgl.showChevron
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 44

      Rectangle {
        anchors.centerIn: parent
        width: 32
        height: 40
        radius: 16
        color: Qt.alpha(tgl.fg, chevMouse.containsMouse ? 0.18 : 0)
      }

      Glyph {
        anchors.centerIn: parent
        text: "\uf054" // fa-chevron-right
        color: tgl.fg
        font.pixelSize: 12
      }

      MouseArea {
        id: chevMouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: tgl.available
        onClicked: tgl.expand()
      }
    }
  }

  // linha de perfil de energia (estilo "radio")
  component PowerRow: Rectangle {
    id: pr

    property string key: ""
    property string desc: ""

    readonly property bool current: qs.ppActive === pr.key

    Layout.fillWidth: true
    implicitHeight: 52
    radius: 12
    color: prArea.containsMouse ? qs.cItem : "transparent"

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 8
      anchors.rightMargin: 10
      spacing: 12

      Glyph {
        text: qs.ppGlyph(pr.key)
        font.pixelSize: 19
        color: pr.current ? qs.cAccent : qs.cText
        Layout.preferredWidth: 24
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Label {
          text: qs.ppName(pr.key)
          font.bold: pr.current
          font.pixelSize: 13
          Layout.fillWidth: true
        }

        Label {
          text: pr.desc
          color: qs.cMuted
          font.pixelSize: 10
          Layout.fillWidth: true
        }
      }

      Glyph {
        visible: pr.current
        text: "\uf00c" // fa-check
        font.pixelSize: 14
        color: qs.cAccent
      }
    }

    MouseArea {
      id: prArea

      anchors.fill: parent
      hoverEnabled: true
      onClicked: qs.setProfile(pr.key)
    }
  }

  // linha de rede Wi-Fi
  component WifiRow: Rectangle {
    id: wr

    required property var modelData

    readonly property var net: modelData
    readonly property bool isOpen: wr.net.security === WifiSecurityType.Open
    readonly property bool asking: qs.pwNetwork === wr.net
    readonly property real strength: qs.norm(wr.net.signalStrength)

    property bool failed: false

    function submit(psk) {
      if (psk.length === 0) {
        return;
      }

      wr.failed = false;
      wr.net.connectWithPsk(psk);
      qs.pwNetwork = null;
    }

    width: ListView.view ? ListView.view.width : 0
    height: wrCol.implicitHeight + 12
    radius: 12
    color: wrArea.containsMouse ? qs.cItem : "transparent"

    Connections {
      target: wr.net

      function onConnectionFailed() {
        wr.failed = true;
      }
    }

    MouseArea {
      id: wrArea

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 44
      hoverEnabled: true

      onClicked: {
        if (wr.net.connected) {
          wr.net.disconnect();
        } else if ((wr.net.known && !wr.failed) || wr.isOpen) {
          wr.failed = false;
          wr.net.connect();
        } else {
          qs.pwNetwork = wr.asking ? null : wr.net;
        }
      }
    }

    ColumnLayout {
      id: wrCol

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 6
      spacing: 6

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        spacing: 10

        Glyph {
          text: "\uf1eb" // fa-wifi
          font.pixelSize: 15
          color: wr.net.connected ? qs.cAccent : qs.cText
          opacity: 0.35 + 0.65 * wr.strength
          Layout.preferredWidth: 22
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          Label {
            text: wr.net.name
            font.bold: wr.net.connected
            font.pixelSize: 13
            Layout.fillWidth: true
          }

          Label {
            visible: text !== ""
            text: wr.failed ? "Falha ao conectar"
              : wr.net.stateChanging ? "Conectando…"
              : wr.net.connected ? "Conectado"
              : wr.net.known ? "Salva"
              : ""
            color: wr.failed ? qs.cError : (wr.net.connected ? qs.cAccent : qs.cMuted)
            font.pixelSize: 10
            Layout.fillWidth: true
          }
        }

        Glyph {
          visible: !wr.isOpen
          text: "\uf023" // fa-lock
          font.pixelSize: 11
          color: qs.cMuted
        }

        // esquecer rede salva
        Rectangle {
          visible: wr.net.known
          implicitWidth: 26
          implicitHeight: 26
          radius: 13
          color: forgetArea.containsMouse ? qs.cItemHi : "transparent"

          Glyph {
            anchors.centerIn: parent
            text: "\u{F01B4}" // md-delete
            font.pixelSize: 13
            color: qs.cMuted
          }

          MouseArea {
            id: forgetArea

            anchors.fill: parent
            hoverEnabled: true
            onClicked: wr.net.forget()
          }
        }
      }

      // campo de senha (rede protegida e ainda não salva)
      RowLayout {
        visible: wr.asking
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 32
          radius: 10
          color: qs.cItemHi
          border.width: 1
          border.color: pw.activeFocus ? qs.cAccent : "transparent"

          TextInput {
            id: pw

            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            echoMode: TextInput.Password
            color: qs.cText
            font.family: qs.nerdFont
            font.pixelSize: 12
            clip: true
            selectByMouse: true

            onVisibleChanged: {
              if (visible) {
                text = "";
                forceActiveFocus();
              }
            }

            onAccepted: wr.submit(text)
            Keys.onEscapePressed: qs.back()
          }

          Label {
            visible: pw.text === ""
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "Senha"
            color: qs.cMuted
          }
        }

        Rectangle {
          implicitWidth: 78
          implicitHeight: 32
          radius: 10
          color: qs.cAccent

          Label {
            anchors.centerIn: parent
            text: "Conectar"
            color: qs.cOnAccent
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            onClicked: wr.submit(pw.text)
          }
        }
      }
    }
  }

  // linha de dispositivo Bluetooth
  component BtRow: Rectangle {
    id: br

    required property var modelData

    readonly property var dev: modelData

    property bool wantConnect: false

    readonly property string status: br.dev.pairing ? "Pareando…"
      : br.dev.connected ? "Conectado"
      : br.dev.paired ? "Pareado"
      : "Disponível"

    width: ListView.view ? ListView.view.width : 0
    height: 46
    radius: 12
    color: brArea.containsMouse ? qs.cItem : "transparent"

    // depois de parear, já conecta
    Connections {
      target: br.dev

      function onPairedChanged() {
        if (br.dev.paired && br.wantConnect && !br.dev.connected) {
          br.wantConnect = false;
          br.dev.connect();
        }
      }
    }

    MouseArea {
      id: brArea

      anchors.fill: parent
      hoverEnabled: true

      onClicked: {
        if (br.dev.connected) {
          br.dev.disconnect();
        } else if (br.dev.paired) {
          br.dev.connect();
        } else {
          br.wantConnect = true;
          br.dev.pair();
        }
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 6
      anchors.rightMargin: 6
      spacing: 10

      Glyph {
        text: qs.btGlyph(br.dev.icon)
        font.pixelSize: 17
        color: br.dev.connected ? qs.cAccent : qs.cText
        Layout.preferredWidth: 22
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Label {
          text: br.dev.name || br.dev.deviceName || br.dev.address
          font.bold: br.dev.connected
          font.pixelSize: 13
          Layout.fillWidth: true
        }

        Label {
          text: br.status
          color: br.dev.connected ? qs.cAccent : qs.cMuted
          font.pixelSize: 10
          Layout.fillWidth: true
        }
      }

      Label {
        visible: br.dev.connected && br.dev.batteryAvailable
        text: Math.round(qs.norm(br.dev.battery) * 100) + "%"
        color: qs.cMuted
        font.pixelSize: 11
      }

      Rectangle {
        visible: br.dev.paired
        implicitWidth: 26
        implicitHeight: 26
        radius: 13
        color: btForgetArea.containsMouse ? qs.cItemHi : "transparent"

        Glyph {
          anchors.centerIn: parent
          text: "\u{F01B4}" // md-delete
          font.pixelSize: 13
          color: qs.cMuted
        }

        MouseArea {
          id: btForgetArea

          anchors.fill: parent
          hoverEnabled: true
          onClicked: br.dev.forget()
        }
      }
    }
  }

  // anel de uso (0..1) desenhado num Canvas; o texto fica no centro
  component Ring: Item {
    id: rg

    property real value: 0
    property real shown: 0
    property string centerText: ""
    property color fillColor: qs.cAccent
    property color trackColor: qs.cItemHi

    implicitWidth: 66
    implicitHeight: 66

    onValueChanged: rg.shown = Math.max(0, Math.min(1, rg.value))
    onShownChanged: cv.requestPaint()
    onFillColorChanged: cv.requestPaint()
    onTrackColorChanged: cv.requestPaint()

    Behavior on shown {
      NumberAnimation {
        duration: 300
        easing.type: Easing.OutCubic
      }
    }

    Canvas {
      id: cv

      anchors.fill: parent

      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      Component.onCompleted: requestPaint()

      onPaint: {
        const ctx = getContext("2d");
        const lw = 8;
        const r = Math.min(width, height) / 2 - lw / 2 - 1;
        const cx = width / 2;
        const cy = height / 2;

        ctx.clearRect(0, 0, width, height);
        ctx.lineWidth = lw;
        ctx.lineCap = "round";

        ctx.strokeStyle = rg.trackColor;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.stroke();

        if (rg.shown > 0.005) {
          ctx.strokeStyle = rg.fillColor;
          ctx.beginPath();
          ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * rg.shown);
          ctx.stroke();
        }
      }
    }

    Label {
      anchors.centerIn: parent
      text: rg.centerText
      font.bold: true
      font.pixelSize: 13
    }
  }

  // cartão com um anel + título + até duas linhas de detalhe
  component StatTile: Rectangle {
    id: st

    property string title: ""
    property string sub: ""
    property string sub2: ""
    property string pct: ""
    property real value: 0

    Layout.fillWidth: true
    implicitHeight: stCol.implicitHeight + 24
    radius: Math.min(qs.moduleRadius, height / 2)
    color: qs.cItem

    ColumnLayout {
      id: stCol

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: 6
      anchors.rightMargin: 6
      spacing: 2

      Ring {
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: 6
        value: st.value
        centerText: st.pct
        fillColor: st.value > 0.9 ? qs.cError : qs.cAccent
      }

      Label {
        text: st.title
        font.bold: true
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }

      Label {
        text: st.sub
        color: qs.cMuted
        font.pixelSize: 10
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }

      Label {
        text: st.sub2 !== "" ? st.sub2 : " "
        color: qs.cMuted
        font.pixelSize: 10
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }
    }
  }

  // linha de áudio: botão de mute + slider + porcentagem
  component AudioRow: RowLayout {
    id: ar

    property var node: null
    property bool isMic: false

    readonly property bool ok: !!(ar.node && ar.node.ready && ar.node.audio)
    readonly property real vol: ar.ok ? ar.node.audio.volume : 0
    readonly property bool muted: ar.ok ? ar.node.audio.muted : false

    function setVol(v) {
      if (ar.ok) {
        ar.node.audio.volume = v;
      }
    }

    function toggleMute() {
      if (ar.ok) {
        ar.node.audio.muted = !ar.node.audio.muted;
      }
    }

    Layout.fillWidth: true
    spacing: 10
    opacity: ar.ok ? 1 : 0.5

    Rectangle {
      implicitWidth: 32
      implicitHeight: 32
      radius: 16
      color: ar.muted ? (muteArea.containsMouse ? qs.cItemHi : qs.cItem) : qs.cAccent

      Glyph {
        anchors.centerIn: parent
        text: ar.isMic
          ? (ar.muted ? "\u{F036D}" : "\u{F036C}")
          : qs.spkGlyph(ar.muted, ar.vol)
        color: ar.muted ? qs.cText : qs.cOnAccent
        font.pixelSize: 15
      }

      MouseArea {
        id: muteArea

        anchors.fill: parent
        hoverEnabled: true
        enabled: ar.ok
        onClicked: ar.toggleMute()
      }
    }

    Item {
      id: sl

      Layout.fillWidth: true
      Layout.preferredHeight: 28

      readonly property real v: Math.max(0, Math.min(1, ar.vol))

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: 4
        color: qs.cItemHi

        Rectangle {
          width: knob.x + knob.width / 2
          height: parent.height
          radius: 4
          color: ar.muted ? qs.cMuted : qs.cAccent
        }
      }

      Rectangle {
        id: knob

        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 8
        x: (sl.width - knob.width) * sl.v
        color: ar.muted ? qs.cMuted : qs.cAccent
        border.width: 2
        border.color: qs.cItem
      }

      MouseArea {
        id: slArea

        anchors.fill: parent
        enabled: ar.ok

        function apply(mx) {
          ar.setVol(Math.max(0, Math.min(1, (mx - knob.width / 2) / (sl.width - knob.width))));
        }

        onPressed: (mouse) => apply(mouse.x)

        onPositionChanged: (mouse) => {
          if (slArea.pressed) {
            apply(mouse.x);
          }
        }
      }
    }

    Label {
      text: Math.round(ar.vol * 100) + "%"
      color: qs.cMuted
      font.pixelSize: 11
      horizontalAlignment: Text.AlignRight
      Layout.preferredWidth: 36
    }
  }

  // slider simples (0..1); só emite moved() ao soltar, pra não metralhar o player com seeks
  component SliderBar: Item {
    id: sb

    property real value: 0
    property bool active: true
    property bool dragging: false
    property real dragValue: 0

    signal moved(real v)

    implicitHeight: 20

    function calc(mx) {
      return Math.max(0, Math.min(1, (mx - sbKnob.width / 2) / (sb.width - sbKnob.width)));
    }

    readonly property real shownValue: sb.dragging ? sb.dragValue : Math.max(0, Math.min(1, sb.value))

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 6
      radius: 3
      color: qs.cItemHi

      Rectangle {
        width: sbKnob.x + sbKnob.width / 2
        height: parent.height
        radius: 3
        color: qs.cAccent
      }
    }

    Rectangle {
      id: sbKnob

      anchors.verticalCenter: parent.verticalCenter
      width: 12
      height: 12
      radius: 6
      x: (sb.width - sbKnob.width) * sb.shownValue
      color: qs.cAccent
      border.width: 2
      border.color: qs.cItem
    }

    MouseArea {
      id: sbArea

      anchors.fill: parent
      enabled: sb.active

      onPressed: (mouse) => {
        sb.dragValue = sb.calc(mouse.x);
        sb.dragging = true;
      }

      onPositionChanged: (mouse) => {
        if (sbArea.pressed) {
          sb.dragValue = sb.calc(mouse.x);
        }
      }

      onReleased: {
        sb.moved(sb.dragValue);
        sb.dragging = false;
      }

      onCanceled: sb.dragging = false
    }
  }

  // botão redondo dos controles de mídia
  component MediaBtn: Rectangle {
    id: mb

    property string glyph: ""
    property bool primary: false
    property bool usable: true

    signal clicked()

    implicitWidth: mb.primary ? 44 : 36
    implicitHeight: mb.implicitWidth
    radius: width / 2
    opacity: mb.usable ? 1 : 0.4
    color: mb.primary
      ? (mbArea.containsMouse ? Qt.lighter(qs.cAccent, 1.1) : qs.cAccent)
      : (mbArea.containsMouse ? qs.cItemHi : "transparent")

    Glyph {
      anchors.centerIn: parent
      text: mb.glyph
      color: mb.primary ? qs.cOnAccent : qs.cText
      font.pixelSize: mb.primary ? 16 : 14
    }

    MouseArea {
      id: mbArea

      anchors.fill: parent
      hoverEnabled: true
      enabled: mb.usable
      onClicked: mb.clicked()
    }
  }

  // ================================================================
  // JANELA
  // ================================================================

  Item {
    id: rootItem

    anchors.fill: parent
    focus: true

    Keys.onEscapePressed: qs.back()

    // clique fora do cartão fecha
    MouseArea {
      anchors.fill: parent
      onClicked: qs.closeRequested()
    }

    Rectangle {
      id: card

      width: 400
      height: content.implicitHeight + 28

      x: parent.width - width - 8
      y: qs.atBottom ? parent.height - height - qs.bottomInset : qs.topInset

      radius: Math.min(qs.moduleRadius, height / 2)
      color: qs.cBg
      border.width: 1
      border.color: qs.cLine
      clip: true

      Behavior on height {
        NumberAnimation {
          duration: 140
          easing.type: Easing.OutCubic
        }
      }

      // engole cliques dentro do cartão
      MouseArea {
        anchors.fill: parent
      }

      ColumnLayout {
        id: content

        x: 14
        y: 14
        width: card.width - 28
        spacing: 10

        // ============ PRINCIPAL ============
        GridLayout {
          visible: qs.page === "main"
          Layout.fillWidth: true
          columns: 2
          columnSpacing: 10
          rowSpacing: 10
          uniformCellWidths: true

          QuickToggle {
            icon: Networking.wifiEnabled ? "\uf1eb" : "\u{F05AA}"
            title: "Wi-Fi"
            subtitle: !Networking.wifiEnabled ? "Desligado"
              : qs.activeWifi ? qs.activeWifi.name
              : "Desconectado"
            active: Networking.wifiEnabled
            available: qs.wifiDevice !== null

            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            onExpand: qs.page = "wifi"
          }

          QuickToggle {
            icon: qs.btOn ? "\u{F00AF}" : "\u{F00B2}"
            title: "Bluetooth"
            subtitle: !qs.btAdapter ? "Indisponível"
              : !qs.btOn ? "Desligado"
              : qs.btFirstConnected ? (qs.btFirstConnected.name || qs.btFirstConnected.deviceName)
              : "Ligado"
            active: qs.btOn
            available: qs.btAdapter !== null

            onToggled: qs.toggleBluetooth()
            onExpand: qs.page = "bt"
          }

          // aceso quando o perfil NÃO é o equilibrado (como no GNOME)
          QuickToggle {
            icon: qs.ppGlyph(qs.ppActive)
            title: "Modo de energia"
            subtitle: qs.ppName(qs.ppActive)
            active: qs.ppActive !== "" && qs.ppActive !== "balanced"
            available: qs.ppAvail.length > 0

            onToggled: qs.cycleProfile()
            onExpand: qs.page = "power"
          }

          // aceso no modo escuro (como o "Dark Style" do GNOME)
          QuickToggle {
            icon: "\u{F0594}" // md-theme-light-dark
            title: "Estilo escuro"
            subtitle: qs.themeBusy ? "Aplicando…"
              : qs.themeFailed ? "Falhou"
              : qs.isDark ? "Escuro"
              : "Claro"
            active: qs.isDark
            showChevron: false

            onToggled: qs.toggleTheme()
          }
        }

        // ============ MÍDIA (MPRIS) ============
        Rectangle {
          id: mediaCard

          readonly property var pl: qs.mprisPlayer

          visible: qs.page === "main" && mediaCard.pl !== null
          Layout.fillWidth: true
          implicitHeight: mediaCol.implicitHeight + 24
          radius: Math.min(qs.moduleRadius, height / 2)
          color: qs.cItem

          ColumnLayout {
            id: mediaCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            RowLayout {
              Layout.fillWidth: true
              spacing: 12

              // capa (ou nota musical se o player não mandou capa)
              Rectangle {
                implicitWidth: 60
                implicitHeight: 60
                radius: 8
                color: qs.cItemHi

                Glyph {
                  anchors.centerIn: parent
                  visible: art.status !== Image.Ready
                  text: "\uf001" // fa-music
                  color: qs.cMuted
                  font.pixelSize: 22
                }

                Image {
                  id: art

                  anchors.fill: parent
                  source: mediaCard.pl ? (mediaCard.pl.trackArtUrl || "") : ""
                  asynchronous: true
                  fillMode: Image.PreserveAspectCrop
                  sourceSize.width: 120
                  sourceSize.height: 120
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 4

                  Label {
                    text: (mediaCard.pl ? (mediaCard.pl.identity || "") : "")
                      + (qs.mprisList.length > 1 ? "  " + (qs.mprisIndex + 1) + "/" + qs.mprisList.length : "")
                    color: qs.cMuted
                    font.pixelSize: 10
                    Layout.fillWidth: true
                  }

                  RoundBtn {
                    visible: qs.mprisList.length > 1
                    glyph: "\uf053"
                    implicitWidth: 22
                    implicitHeight: 22
                    onClicked: qs.mprisCycle(-1)
                  }

                  RoundBtn {
                    visible: qs.mprisList.length > 1
                    glyph: "\uf054"
                    implicitWidth: 22
                    implicitHeight: 22
                    onClicked: qs.mprisCycle(1)
                  }
                }

                Label {
                  text: mediaCard.pl ? (mediaCard.pl.trackTitle || "Sem título") : ""
                  font.bold: true
                  font.pixelSize: 13
                  Layout.fillWidth: true
                }

                Label {
                  text: mediaCard.pl ? (mediaCard.pl.trackArtist || mediaCard.pl.trackAlbum || "") : ""
                  color: qs.cMuted
                  font.pixelSize: 11
                  Layout.fillWidth: true
                }
              }
            }

            // progresso (só quando o player informa a duração)
            RowLayout {
              visible: qs.mprisLen > 0
              Layout.fillWidth: true
              spacing: 8

              Label {
                text: qs.fmtTime(qs.mprisPos)
                color: qs.cMuted
                font.pixelSize: 10
                Layout.preferredWidth: 36
              }

              SliderBar {
                Layout.fillWidth: true
                value: qs.mprisLen > 0 ? qs.mprisPos / qs.mprisLen : 0
                active: !!(mediaCard.pl && mediaCard.pl.canSeek)

                onMoved: (v) => {
                  const p = qs.mprisPlayer;

                  if (p && p.canSeek) {
                    p.position = v * qs.mprisLen;
                  }
                }
              }

              Label {
                text: qs.fmtTime(qs.mprisLen)
                color: qs.cMuted
                font.pixelSize: 10
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 36
              }
            }

            RowLayout {
              Layout.alignment: Qt.AlignHCenter
              spacing: 14

              MediaBtn {
                glyph: "\uf048" // fa-step-backward
                usable: !!(mediaCard.pl && mediaCard.pl.canGoPrevious)
                onClicked: mediaCard.pl.previous()
              }

              MediaBtn {
                primary: true
                glyph: (mediaCard.pl && mediaCard.pl.isPlaying) ? "\uf04c" : "\uf04b" // pause / play
                usable: !!(mediaCard.pl && mediaCard.pl.canControl)
                onClicked: mediaCard.pl.togglePlaying()
              }

              MediaBtn {
                glyph: "\uf051" // fa-step-forward
                usable: !!(mediaCard.pl && mediaCard.pl.canGoNext)
                onClicked: mediaCard.pl.next()
              }
            }
          }
        }

        // ============ ÁUDIO (saída + microfone) ============
        Rectangle {
          visible: qs.page === "main"
          Layout.fillWidth: true
          implicitHeight: audioCol.implicitHeight + 16
          radius: Math.min(qs.moduleRadius, height / 2)
          color: qs.cItem

          ColumnLayout {
            id: audioCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 14
            spacing: 2

            AudioRow {
              node: Pipewire.defaultAudioSink
            }

            AudioRow {
              node: Pipewire.defaultAudioSource
              isMic: true
            }
          }
        }

        // ============ CPU / RAM / DISCO ============
        GridLayout {
          visible: qs.page === "main"
          Layout.fillWidth: true
          columns: 3
          columnSpacing: 10
          rowSpacing: 10
          uniformCellWidths: true

          StatTile {
            title: "CPU"
            sub: "em uso"
            value: qs.cpuUsage
            pct: Math.round(qs.cpuUsage * 100) + "%"
          }

          StatTile {
            title: "RAM"
            sub: qs.fmtGb(qs.ramUsedGb) + " usados"
            sub2: "de " + qs.fmtGb(qs.ramTotalGb)
            value: qs.ramFrac
            pct: Math.round(qs.ramFrac * 100) + "%"
          }

          StatTile {
            title: "Disco"
            sub: qs.fmtGb(qs.diskFreeGb) + " livres"
            sub2: "de " + qs.fmtGb(qs.diskTotalGb)
            value: qs.diskUsedFrac
            pct: Math.round(qs.diskUsedFrac * 100) + "%"
          }
        }

        // ============ MODO DE ENERGIA ============
        ColumnLayout {
          visible: qs.page === "power"
          Layout.fillWidth: true
          spacing: 6

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RoundBtn {
              glyph: "\uf053"
              onClicked: qs.back()
            }

            Label {
              text: "Modo de energia"
              font.bold: true
              font.pixelSize: 15
              Layout.fillWidth: true
            }

            Label {
              visible: qs.batteryText !== ""
              text: qs.batteryText
              color: qs.cMuted
              font.pixelSize: 12
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: qs.cLine
          }

          Label {
            visible: qs.ppAvail.length === 0
            text: "power-profiles-daemon indisponível"
            color: qs.cMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            Layout.bottomMargin: 14
          }

          PowerRow {
            visible: qs.ppAvail.indexOf("performance") !== -1
            key: "performance"
            desc: qs.ppPerfNote !== "" ? "Alto desempenho, " + qs.ppPerfNote
              : "Mais desempenho, consome mais bateria"
          }

          PowerRow {
            visible: qs.ppAvail.indexOf("balanced") !== -1
            key: "balanced"
            desc: "Desempenho e consumo em equilíbrio"
          }

          PowerRow {
            visible: qs.ppAvail.indexOf("power-saver") !== -1
            key: "power-saver"
            desc: "Reduz o desempenho pra durar mais"
          }
        }

        // ============ WI-FI ============
        ColumnLayout {
          visible: qs.page === "wifi"
          Layout.fillWidth: true
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RoundBtn {
              glyph: "\uf053" // fa-chevron-left
              onClicked: qs.back()
            }

            Label {
              text: "Wi-Fi"
              font.bold: true
              font.pixelSize: 15
              Layout.fillWidth: true
            }

            Toggle {
              checked: Networking.wifiEnabled
              onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: qs.cLine
          }

          Label {
            visible: !Networking.wifiEnabled
            text: "Wi-Fi desligado"
            color: qs.cMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            Layout.bottomMargin: 14
          }

          Label {
            visible: Networking.wifiEnabled && qs.wifiRows.length === 0
            text: qs.wifiDevice ? "Procurando redes…" : "Nenhum adaptador Wi-Fi"
            color: qs.cMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            Layout.bottomMargin: 14
          }

          ListView {
            visible: Networking.wifiEnabled && qs.wifiRows.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 280)
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: qs.wifiRows

            delegate: WifiRow {}
          }
        }

        // ============ BLUETOOTH ============
        ColumnLayout {
          visible: qs.page === "bt"
          Layout.fillWidth: true
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RoundBtn {
              glyph: "\uf053"
              onClicked: qs.back()
            }

            Label {
              text: "Bluetooth"
              font.bold: true
              font.pixelSize: 15
              Layout.fillWidth: true
            }

            Label {
              visible: qs.btAdapter && qs.btAdapter.discovering
              text: "Procurando…"
              color: qs.cMuted
              font.pixelSize: 11
            }

            Toggle {
              checked: qs.btOn
              onToggled: qs.toggleBluetooth()
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: qs.cLine
          }

          Label {
            visible: !qs.btOn
            text: qs.btAdapter ? "Bluetooth desligado" : "Nenhum adaptador Bluetooth"
            color: qs.cMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            Layout.bottomMargin: 14
          }

          Label {
            visible: qs.btOn && qs.btRows.length === 0
            text: "Nenhum dispositivo por perto"
            color: qs.cMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            Layout.bottomMargin: 14
          }

          ListView {
            visible: qs.btOn && qs.btRows.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 280)
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: qs.btRows

            delegate: BtRow {}
          }
        }
      }
    }
  }
}
