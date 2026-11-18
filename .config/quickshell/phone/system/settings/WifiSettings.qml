// system/settings/WifiSettings.qml — estado, leitura e ações de redes Wi-Fi

import QtQuick

QtObject {
  id: self

  required property var settings

  property bool radioOn: true
  property var networks: []
  property bool networkManagerMissing: false
  property var accessPoint: ({})

  readonly property string scanScript: `
    if ! command -v nmcli >/dev/null 2>&1; then echo "nonm=1"; exit 0; fi
    [ "$1" = "1" ] && nmcli device wifi rescan >/dev/null 2>&1 &
    echo "radio=$(nmcli radio wifi 2>/dev/null)"
    hs=0
    nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -q '^Hotspot:' && hs=1
    if command -v create_ap >/dev/null 2>&1; then
      echo "createap=1"
      create_ap --list-running 2>/dev/null | awk '$1 ~ /^[0-9]+$/ {f=1} END{exit !f}' && hs=1
    fi
    echo "hotspot=$hs"
    up=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
    echo "up=$up"
    [ -n "$up" ] && nmcli -t -f DEVICE,TYPE device 2>/dev/null | grep -q "^$up:wifi$" && echo "upwifi=1"
    echo "apcand=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: -v u="$up" '$2=="wifi" && $1!=u {n++} END{print n+0}')"
    if command -v iw >/dev/null 2>&1; then
      if iw list 2>/dev/null | grep -Eq '#\\{ *managed *\\}.*#\\{[^}]*AP'; then echo "concurrent=1"; else echo "concurrent=0"; fi
    fi
    nmcli -t -f NAME connection show 2>/dev/null | sed 's/^/saved|/'
    nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan no 2>/dev/null | sed 's/^/net:/'
  `

  function parseScan(text) {
    const kv = settings.setKv(text);
    const saved = {};
    const best = {};
    for (const line of text.split("\n")) {
      if (line.indexOf("saved|") === 0) {
        saved[line.slice(6).trim()] = true;
      } else if (line.indexOf("net:") === 0) {
        const fields = line.slice(4).split(":");
        const ssid = fields.slice(3).join(":").replace(/\\:/g, ":");
        if (ssid === "") continue;
        const network = {
          ssid, inuse: fields[0] === "*", signal: parseInt(fields[1]) || 0,
          sec: fields[2] || "", saved: false
        };
        if (!best[ssid] || network.inuse || (!best[ssid].inuse && network.signal > best[ssid].signal))
          best[ssid] = network;
      }
    }
    const networks = Object.keys(best).map(name => {
      best[name].saved = !!saved[name];
      return best[name];
    });
    networks.sort((a, b) => (b.inuse - a.inuse) || (b.signal - a.signal));
    return {
      networkManagerMissing: kv.nonm === "1",
      radioOn: kv.radio !== "disabled",
      hotspotOn: kv.hotspot === "1",
      accessPoint: {
        loaded: true, up: kv.up || "", upwifi: kv.upwifi || "",
        apcand: kv.apcand || "0", concurrent: kv.concurrent,
        createap: kv.createap || ""
      },
      networks
    };
  }

  function toggleRadio() {
    settings.setRun("Wi-Fi…", "nmcli radio wifi " + (radioOn ? "off" : "on"), [], null,
      radioOn ? "Wi-Fi desligado" : "Wi-Fi ligado");
  }

  function connectNetwork(index) {
    const network = networks[index];
    if (!network) return;
    if (network.inuse) {
      settings.setRun("Desconectando…", 'nmcli connection down id "$1"', [network.ssid], null, "Desconectado de " + network.ssid);
    } else if (network.saved) {
      settings.setRun("Conectando…", 'nmcli connection up id "$1"', [network.ssid], null, "Conectado a " + network.ssid);
    } else if (network.sec === "" || network.sec === "--") {
      settings.setRun("Conectando…", 'nmcli device wifi connect "$1"', [network.ssid], null, "Conectado a " + network.ssid);
    } else {
      settings.setFormTitle = network.ssid;
      settings.setFormHint = "Digite a senha da rede";
      settings.setFormAction = "wifipw";
      settings.setFormCtx = network.ssid;
      settings.setFormFields = [{ label: "Senha", value: "", mask: true }];
      settings.setFormFocus = 0;
      settings.setForm = true;
    }
  }

  function forgetNetwork(network) {
    if (!network) return;
    settings.setRun("Esquecendo rede…", 'nmcli connection delete id "$1"', [network.ssid], null, "Rede esquecida: " + network.ssid);
  }
}
