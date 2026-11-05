// logic/SystemInfo.qml — Info do sistema (fastfetch-like)
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "info".
// Acesso de fora:  phone.info.<membro>

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // ================================================================
  // INFO DO SISTEMA
  // ================================================================

  property var sysInfo: ({})

  function refreshInfo() {
    sysProc.running = true;
  }

  function fmtUptime(sec) {
    const d = Math.floor(sec / 86400);
    const h = Math.floor((sec % 86400) / 3600);
    const m = Math.floor((sec % 3600) / 60);

    if (d > 0)
      return d + "d " + h + "h " + m + "m";

    return h + "h " + m + "m";
  }

  readonly property real memTotalGiB:
    sysInfo.memTotal ? sysInfo.memTotal / 1048576 : 0

  readonly property real memUsedGiB:
    sysInfo.memUsed ? sysInfo.memUsed / 1048576 : 0

  readonly property real memRatio:
    memTotalGiB > 0 ? Math.min(1, memUsedGiB / memTotalGiB) : 0

  readonly property var infoRows: [
    { l: "Sistema", v: sysInfo.os || "--" },
    { l: "Kernel",  v: sysInfo.kernel || "--" },
    { l: "WM",      v: sysInfo.wm || "--" },
    { l: "CPU",     v: sysInfo.cpu || "--" },
    { l: "Uptime",  v: sysInfo.uptime ? fmtUptime(sysInfo.uptime) : "--" },
    { l: "Pacotes", v: sysInfo.pkgs ? sysInfo.pkgs + " (pacman)" : "--" }
  ]

  Process {
    id: sysProc

    running: false

    command: ["sh", "-c", `
      . /etc/os-release
      echo "user=$USER"
      echo "host=$(cat /etc/hostname 2>/dev/null || uname -n)"
      echo "os=$PRETTY_NAME"
      echo "kernel=$(uname -r)"
      echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/(R)//g; s/(TM)//g; s/ CPU//; s/@.*//; s/^ *//; s/ *$//')"
      echo "mem=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print t, t-a}' /proc/meminfo)"
      echo "uptime=$(cut -d' ' -f1 /proc/uptime)"
      echo "pkgs=$(pacman -Qq 2>/dev/null | wc -l)"
    `]

    stdout: StdioCollector {
      onStreamFinished: {
        const out = {};
        const lines = text.split("\n");

        for (let i = 0; i < lines.length; i++) {
          const k = lines[i].indexOf("=");

          if (k > 0)
            out[lines[i].slice(0, k)] = lines[i].slice(k + 1).trim();
        }

        const mem = (out.mem || "").split(" ");

        phone.info.sysInfo = {
          user: out.user || Quickshell.env("USER"),
          host: out.host || "",
          os: out.os || "",
          kernel: out.kernel || "",
          cpu: out.cpu || "",
          wm: Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland",
          uptime: parseFloat(out.uptime) || 0,
          pkgs: parseInt(out.pkgs) || 0,
          memTotal: parseFloat(mem[0]) || 0,
          memUsed: parseFloat(mem[1]) || 0
        };
      }
    }
  }
}
