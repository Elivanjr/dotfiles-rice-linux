// logic/SystemStatus.qml — Bateria, Wi-Fi, Bluetooth da barra de status
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "sys".
// Acesso de fora:  phone.sys.<membro>

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // ================================================================
  // STATUS DO SISTEMA (bateria, wifi, bluetooth)
  // ================================================================

  property int batPct: -1                    // -1 = sem bateria

  property string batState: ""               // Charging | Discharging | Full ...

  property string wifiState: "disconnected"  // connected | disconnected | off

  property int wifiSignal: 0                 // 0-100

  property bool ethUp: false

  property bool btOn: false

  property bool btConnected: false

  readonly property int wifiBars: {
    if (wifiState === "connected") {
      if (wifiSignal >= 80) return 4;
      if (wifiSignal >= 55) return 3;
      if (wifiSignal >= 30) return 2;
      return 1;
    }

    return ethUp ? 4 : 0;
  }

  readonly property string wifiLabel:
    wifiState === "connected" ? "Wifi"
      : ethUp ? "Cabo"
      : wifiState === "off" ? "Wifi off"
      : "Sem wifi"

  function refreshStatus() {
    if (!statusProc.running)
      statusProc.running = true;
  }

  Timer {
    interval: 5000
    running: phone.panelOpen
    repeat: true
    triggeredOnStart: true

    onTriggered: phone.sys.refreshStatus()
  }

  Process {
    id: statusProc

    running: false

    command: ["sh", "-c", `
      for d in /sys/class/power_supply/BAT*; do
        [ -r "$d/capacity" ] || continue
        echo "bat=$(cat "$d/capacity")"
        echo "batstate=$(cat "$d/status" 2>/dev/null)"
        break
      done

      if command -v nmcli >/dev/null 2>&1; then
        if [ "$(nmcli radio wifi 2>/dev/null)" = "disabled" ]; then
          echo "wifi=off"
        elif nmcli -t -f TYPE,STATE device 2>/dev/null | grep -q '^wifi:connected'; then
          echo "wifi=connected"
          echo "signal=$(nmcli -t -f ACTIVE,SIGNAL device wifi list --rescan no 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')"
        else
          echo "wifi=disconnected"
        fi

        nmcli -t -f TYPE,STATE device 2>/dev/null | grep -q '^ethernet:connected' && echo "eth=1"
      else
        q=$(awk 'NR>2{gsub(/[.]/,"",$3); print $3; exit}' /proc/net/wireless 2>/dev/null)

        if [ -n "$q" ]; then
          echo "wifi=connected"
          echo "signal=$((q * 100 / 70))"
        else
          echo "wifi=disconnected"
        fi
      fi

      if command -v bluetoothctl >/dev/null 2>&1; then
        case "$(timeout 2 bluetoothctl show 2>/dev/null)" in
          *"Powered: yes"*)
            echo "bt=1"
            [ -n "$(timeout 2 bluetoothctl devices Connected 2>/dev/null)" ] && echo "btconn=1"
            ;;
        esac
      fi
    `]

    stdout: StdioCollector {
      onStreamFinished: {
        const o = {};
        const lines = text.split("\n");

        for (let i = 0; i < lines.length; i++) {
          const k = lines[i].indexOf("=");

          if (k > 0)
            o[lines[i].slice(0, k)] = lines[i].slice(k + 1).trim();
        }

        const b = parseInt(o.bat);

        phone.sys.batPct = isNaN(b) ? -1 : Math.max(0, Math.min(100, b));
        phone.sys.batState = o.batstate || "";

        phone.sys.wifiState = o.wifi || "disconnected";

        const sg = parseInt(o.signal);

        phone.sys.wifiSignal = isNaN(sg) ? 0 : Math.max(0, Math.min(100, sg));
        phone.sys.ethUp = o.eth === "1";

        phone.sys.btOn = o.bt === "1";
        phone.sys.btConnected = o.btconn === "1";
      }
    }
  }
}
