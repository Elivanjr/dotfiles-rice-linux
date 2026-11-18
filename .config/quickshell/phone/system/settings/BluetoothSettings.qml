// system/settings/BluetoothSettings.qml — descoberta e conexão de aparelhos

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var settings

  property bool powered: false
  property bool scanning: false
  property var devices: []
  property bool receiving: false
  property string receivedFile: ""
  property string sendMac: ""
  property string sendName: ""

  readonly property string scanScript: `
    command -v bluetoothctl >/dev/null 2>&1 || { echo "power=0"; exit 0; }
    out=$(timeout 3 bluetoothctl show 2>/dev/null)
    case "$out" in *"Powered: yes"*) echo "power=1";; *) echo "power=0";; esac
    timeout 6 bluetoothctl devices 2>/dev/null | head -25 | while read -r _ mac name; do
      info=$(timeout 2 bluetoothctl info "$mac" 2>/dev/null)
      p=0; c=0
      case "$info" in *"Paired: yes"*) p=1;; esac
      case "$info" in *"Connected: yes"*) c=1;; esac
      echo "dev|$mac|$p|$c|$name"
      case "$info" in *"00001105-0000-1000-8000-00805f9b34fb"*) echo "opp|$mac";; esac
      if [ "$c" = 1 ]; then
        b=$(printf '%s\\n' "$info" | sed -n 's/^.*Battery Percentage:.*(\\([0-9]*\\)).*$/\\1/p' | head -1)
        if [ -z "$b" ] && command -v upower >/dev/null 2>&1; then
          u=$(upower -e 2>/dev/null | grep -i "$(echo "$mac" | tr ':' '_')" | head -1)
          if [ -n "$u" ]; then
            b=$(upower -i "$u" 2>/dev/null | sed -n 's/^ *percentage: *\\([0-9]*\\)%.*$/\\1/p' | head -1)
          fi
        fi
        if [ -n "$b" ]; then echo "bat|$mac|$b"; fi
      fi
    done
  `

  function parseScan(text) {
    const kv = settings.setKv(text);
    const devs = [];
    const bats = {};
    const opps = {};

    for (const line of text.split("\n")) {
      if (line.indexOf("dev|") === 0) {
        const f = line.split("|");
        devs.push({
          mac: f[1], paired: f[2] === "1", connected: f[3] === "1",
          battery: -1, opp: false, name: f.slice(4).join("|").trim()
        });
      } else if (line.indexOf("bat|") === 0) {
        const f = line.split("|");
        const value = parseInt(f[2]);
        if (!isNaN(value)) bats[f[1]] = Math.max(0, Math.min(100, value));
      } else if (line.indexOf("opp|") === 0) {
        opps[line.split("|")[1]] = true;
      }
    }

    for (const device of devs) {
      if (device.connected && bats[device.mac] !== undefined)
        device.battery = bats[device.mac];
      device.opp = !!opps[device.mac];
    }

    devs.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired));
    return { powered: kv.power === "1", devices: devs };
  }

  function startScan() {
    if (scanning || !powered)
      return;

    scanning = true;
    scanProc.running = true;
    settings.setStatus = "Buscando dispositivos…";
  }

  function activateDevice(index) {
    const device = devices[index];
    if (!device)
      return;

    const name = device.name !== "" ? device.name : device.mac;
    if (device.connected) {
      settings.setRun("Desconectando…", 'bluetoothctl disconnect "$1"', [device.mac], null, "Desconectado de " + name);
    } else {
      settings.setRun("Conectando a " + name + "…", `
        mac="$1"
        info=$(bluetoothctl info "$mac" 2>/dev/null)
        case "$info" in *"Paired: yes"*) ;; *) bluetoothctl pair "$mac" ;; esac
        bluetoothctl trust "$mac" >/dev/null 2>&1
        out=$(bluetoothctl connect "$mac" 2>&1)
        echo "$out"
        case "$out" in *successful*) exit 0;; *) exit 1;; esac
      `, [device.mac], null, "Conectado a " + name);
    }
  }

  function togglePower() {
    stopReceiving();
    settings.setRun("Bluetooth…",
      powered ? "bluetoothctl power off" : "rfkill unblock bluetooth 2>/dev/null; bluetoothctl power on",
      [], null, powered ? "Bluetooth desligado" : "Bluetooth ligado");
  }

  function pickFile(device) {
    if (!device || !device.connected || !device.opp || settings.setBusy)
      return;

    sendMac = device.mac;
    sendName = device.name !== "" ? device.name : device.mac;
    settings.setKeep = true;
    const files = settings.phone.files;
    files.filesPick = true;
    files.filesPickUpload = false;
    files.filesPickAi = false;
    files.filesPickBt = true;
    files.filesReturnView = "settings";
    files.filesDir = files.homeDir;
    settings.phone.view = "files";
  }

  function sendFile(path) {
    if (sendMac === "" || !path)
      return;
    settings.setRun("Enviando a " + sendName + "… confirme no aparelho", sendScript,
      [sendMac, path], null, "Enviado a " + sendName);
  }

  readonly property string sendScript: `
    rm_session() { busctl --user call org.bluez.obex /org/bluez/obex org.bluez.obex.Client1 RemoveSession o "$1" >/dev/null 2>&1; }
    send_file() {
      mac="$1"; f="$2"
      command -v busctl >/dev/null 2>&1 || { echo "busctl não encontrado"; return 1; }
      [ -r "$f" ] || { echo "Não consegui ler o arquivo"; return 1; }
      out=$(busctl --user call org.bluez.obex /org/bluez/obex org.bluez.obex.Client1 CreateSession 'sa{sv}' "$mac" 1 Target s opp 2>&1) || { echo "OBEX indisponível (instale bluez-obex)"; return 1; }
      sess=$(printf '%s\\n' "$out" | sed -n 's/^o "\\(.*\\)"$/\\1/p')
      [ -n "$sess" ] || { echo "Não abriu a sessão OBEX"; return 1; }
      out=$(busctl --user call org.bluez.obex "$sess" org.bluez.obex.ObjectPush1 SendFile s "$f" 2>&1) || { rm_session "$sess"; echo "O aparelho recusou o envio"; return 1; }
      tr=$(printf '%s\\n' "$out" | sed -n 's/^oa{sv} "\\([^"]*\\)".*$/\\1/p')
      last=""; n=0
      while [ "$n" -lt 300 ]; do
        s=$(busctl --user get-property org.bluez.obex "$tr" org.bluez.obex.Transfer1 Status 2>/dev/null | sed -n 's/^s "\\(.*\\)"$/\\1/p')
        [ -n "$s" ] || break
        last="$s"; case "$s" in complete|error) break;; esac
        sleep 1; n=$((n + 1))
      done
      if [ "$n" -ge 300 ]; then
        busctl --user call org.bluez.obex "$tr" org.bluez.obex.Transfer1 Cancel >/dev/null 2>&1
        rm_session "$sess"; echo "Tempo esgotado esperando o aparelho aceitar"; return 1
      fi
      rm_session "$sess"
      case "$last" in complete|active) return 0;; error) echo "A transferência falhou"; return 1;; *) echo "O aparelho recusou ou cancelou o envio"; return 1;; esac
    }
    send_file "$@"
  `

  readonly property string receiveScript: `
    dir=$(xdg-user-dir DOWNLOAD 2>/dev/null); [ -n "$dir" ] || dir="$HOME/Downloads"
    dir="$dir/Bluetooth"; mkdir -p "$dir" || { echo "err|Não consegui criar $dir"; exit 1; }
    obx=""; for c in /usr/lib/bluetooth/obexd /usr/libexec/bluetooth/obexd; do [ -x "$c" ] && { obx="$c"; break; }; done
    [ -n "$obx" ] || obx=$(command -v obexd)
    [ -n "$obx" ] || { echo "err|obexd não encontrado (instale bluez-obex)"; exit 1; }
    systemctl --user stop obex.service >/dev/null 2>&1
    bluetoothctl pairable on >/dev/null 2>&1; bluetoothctl discoverable-timeout 0 >/dev/null 2>&1; bluetoothctl discoverable on >/dev/null 2>&1
    "$obx" -n -a -r "$dir" >/dev/null 2>&1 & pid=$!
    cleanup() { kill "$pid" 2>/dev/null; bluetoothctl discoverable off >/dev/null 2>&1; bluetoothctl discoverable-timeout 180 >/dev/null 2>&1; }
    trap cleanup EXIT; trap 'exit 0' TERM INT HUP
    sleep 1; kill -0 "$pid" 2>/dev/null || { echo "err|obexd não iniciou"; exit 1; }
    echo "ok|$dir"; seen=$(mktemp); ls -1 "$dir" > "$seen"
    while kill -0 "$pid" 2>/dev/null; do
      sleep 1
      ls -1 "$dir" | while IFS= read -r f; do grep -qxF -- "$f" "$seen" || { echo "$f" >> "$seen"; echo "got|$f"; }; done
    done
    rm -f "$seen"; echo "err|o receptor parou"
  `

  function toggleReceiving() {
    if (receiving) {
      stopReceiving();
      settings.setStatus = "Recebimento desligado";
      settings.setStatusClear.restart();
      return;
    }
    if (!powered) return;
    receivedFile = "";
    receiving = true;
    receiveProc.running = true;
    settings.setStatus = "Notebook visível para receber arquivos";
  }

  function stopReceiving() {
    if (!receiving) return;
    receiveProc.running = false;
    receiving = false;
    receivedFile = "";
  }

  Connections {
    target: settings.phone
    function onPanelOpenChanged() {
      if (!settings.phone.panelOpen)
        self.stopReceiving();
    }
  }

  Process {
    id: receiveProc
    command: ["sh", "-c", self.receiveScript, "sh"]
    stdout: SplitParser {
      onRead: data => {
        const line = data.trim();
        if (line.indexOf("got|") === 0) {
          self.receivedFile = line.slice(4);
          settings.setStatus = "Recebendo " + line.slice(4);
          settings.setStatusClear.restart();
        } else if (line.indexOf("err|") === 0) {
          self.receiving = false;
          settings.setStatus = "Falhou: " + line.slice(4);
          settings.setStatusClear.restart();
        }
      }
    }
    onExited: self.receiving = false
  }

  Process {
    id: scanProc
    command: ["bluetoothctl", "--timeout", "12", "scan", "on"]
    onExited: {
      self.scanning = false;
      settings.setStatus = "";
      settings.setRefresh(false);
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: self.scanning
    onTriggered: settings.setRefresh(false)
  }
}
