// system/settings/HotspotSettings.qml — credenciais e planejamento do ponto de acesso

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var settings

  property string ssid: ""
  property string password: ""
  property bool enabled: false

  readonly property string qrPath: settings.setQrPath

  readonly property var plan: {
    const a = settings.setAp;
    if (!a.loaded)
      return { id: "loading", text: "Verificando…" };

    let source = "";
    for (let i = 0; i < settings.setNets.length; i++) {
      if (settings.setNets[i].inuse)
        source = settings.setNets[i].ssid;
    }

    if (!a.up)
      return { id: "none", text: "Sem internet para compartilhar" };
    if (a.upwifi !== "1")
      return { id: "wired", text: "Compartilha o cabo (" + a.up + ")" };

    const wifi = source !== "" ? "o Wi-Fi " + source : "o Wi-Fi";
    if (parseInt(a.apcand || "0") > 0)
      return { id: "second", text: "Compartilha " + wifi + " (2ª placa)" };
    if (a.concurrent === "0")
      return { id: "nosupport", text: "A placa não divide o Wi-Fi que usa" };
    if (a.createap === "1")
      return { id: "concurrent", text: "Compartilha " + wifi + " (simultâneo)" };
    return { id: "needtool", text: "Precisa do create_ap para dividir o Wi-Fi" };
  }

  function showQr() {
    const esc = value => String(value).replace(/([\\;,:\"])/g, "\\$1");
    const text = "WIFI:T:WPA;S:" + esc(ssid) + ";P:" + esc(password) + ";;";
    qrProc.environment = ({ "QS_QR": text });
    qrProc.running = true;
  }

  function toggle() {
    if (enabled) {
      settings.setRun("Desligando compartilhamento…", `
        nmcli connection down Hotspot >/dev/null 2>&1
        rc=0
        if command -v create_ap >/dev/null 2>&1; then
          pid=$(create_ap --list-running 2>/dev/null | awk '$1 ~ /^[0-9]+$/ {print $1; exit}')
          if [ -n "$pid" ]; then pkexec create_ap --stop "$pid"; rc=$?; fi
        fi
        exit $rc
      `, [], null, "Compartilhamento desligado");
      return;
    }

    const nextPlan = plan;
    switch (nextPlan.id) {
    case "loading":
      settings.setStatus = "Verificando a conexão… tente de novo";
      settings.setStatusClear.restart();
      return;
    case "none":
      settings.setShowCard("Sem internet para compartilhar", "O notebook não está conectado a nenhuma rede. Conecte-o a um Wi-Fi ou a um cabo e tente de novo.");
      return;
    case "nosupport":
      settings.setShowCard("Sua placa não divide o Wi-Fi", "Esta placa Wi-Fi não consegue ficar conectada e ser ponto de acesso ao mesmo tempo. Use um cabo de rede, ou um adaptador Wi-Fi USB como segunda placa.");
      return;
    case "needtool":
      settings.setShowCard("Falta o create_ap", "Sua placa aceita dividir o Wi-Fi, mas é preciso o create_ap (pacote linux-wifi-hotspot, no AUR) para criar a rede. Depois de instalar, ligue de novo.");
      return;
    }

    if (ssid === "" || password.length < 8) {
      settings.setOpenHotspotForm(true);
      return;
    }
    start(nextPlan.id);
  }

  function start(planId) {
    settings.setRun("Ligando compartilhamento…", `
      plan="$2"
      up=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
      nmcli radio wifi on >/dev/null 2>&1
      nmcli connection delete Hotspot >/dev/null 2>&1
      if [ "$plan" = "concurrent" ]; then
        rt="$XDG_RUNTIME_DIR"; [ -n "$rt" ] || rt=/tmp
        log="$rt/qs-phone-create_ap.log"; cfg=$(mktemp); chmod 600 "$cfg"
        freq=$(iw dev "$up" link 2>/dev/null | awk '/freq:/ {print int($2); exit}')
        extra=""
        if [ -n "$freq" ]; then
          if [ "$freq" -lt 3000 ]; then extra=$(printf 'FREQ_BAND=2.4\\nCHANNEL=%s' $(((freq - 2407) / 5)))
          else extra=$(printf 'FREQ_BAND=5\\nCHANNEL=%s' $(((freq - 5000) / 5))); fi
        fi
        {
          printf 'WIFI_IFACE=%s\\nINTERNET_IFACE=%s\\nSSID=%s\\nPASSPHRASE=%s\\nNO_HAVEGED=1\\n' "$up" "$up" "$1" "$QS_PW"
          [ -n "$extra" ] && printf '%s\\n' "$extra"
        } > "$cfg"
        : > "$log"; setsid pkexec create_ap --config "$cfg" > "$log" 2>&1 < /dev/null & pid=$!
        i=0
        while [ "$i" -lt 180 ]; do
          sleep 0.5; i=$((i + 1))
          if create_ap --list-running 2>/dev/null | awk '$1 ~ /^[0-9]+$/ {f=1} END{exit !f}'; then rm -f "$cfg"; echo "ok"; exit 0; fi
          if ! kill -0 "$pid" 2>/dev/null; then rm -f "$cfg"; grep -v '^$' "$log" | tail -n 6; exit 1; fi
        done
        rm -f "$cfg"; echo "Tempo esgotado esperando o ponto de acesso subir"; exit 1
      fi
      ap=$(nmcli -t -f DEVICE,TYPE device | awk -F: -v u="$up" '$2=="wifi" && $1!=u {print $1; exit}')
      [ -n "$ap" ] || { echo "Nenhuma placa Wi-Fi livre"; exit 1; }
      nmcli device wifi hotspot ifname "$ap" con-name Hotspot ssid "$1" password "$QS_PW"
    `, [ssid, planId], ({ "QS_PW": password }), "Compartilhando internet: " + ssid);
  }

  Process {
    id: qrProc
    command: ["sh", "-c", 'qrencode -s 6 -m 2 -o "$1" "$QS_QR" 2>&1', "sh", qrPath]
    onExited: (code, status) => {
      qrProc.environment = ({});
      if (code === 0) {
        settings.setCardTitle = "Conectar o celular";
        settings.setCardBody = "";
        settings.setCardRev++;
        settings.setCardImage = qrPath;
        settings.setCardOn = true;
      } else {
        settings.setShowCard("QR Code indisponível", "Instale o qrencode (pacman -S qrencode) para gerar o QR Code.");
      }
    }
  }
}
