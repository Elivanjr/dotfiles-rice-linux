// apps/screenshare/ScreenShareApp.qml — Compartilhar tela: unir/espelhar monitor externo (hyprctl eval)
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "share".
// Acesso de fora:  phone.share.<membro>

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // ================================================================
  // COMPARTILHAR TELA (hyprctl eval, Lua do Hyprland)
  // ================================================================

  property var shareMonitors: []          // monitores externos (HDMI, VGA, DP...)

  property var shareInternal: ({ name: "eDP-1", width: 1366, scale: 1 })

  property bool shareChecking: false

  property string shareStep: "mode"       // mode | profile | done

  property int shareSel: 0

  property string shareStatus: ""

  // true depois do perfil Trabalho (tira borda/espaço/arredondado);
  // pra desfazer é preciso um `hyprctl reload`
  property bool shareBorderless: false

  readonly property bool shareHasExt: shareMonitors.length > 0

  readonly property var shareOpts:
    shareStep === "mode"
      ? [
          {
            act: "extend", icon: "extend",
            t: "Unir telas",
            d: "Estende o desktop para a tela externa."
          },
          {
            act: "mirror", icon: "mirror",
            t: "Espelhar tela",
            d: "Mostra a mesma imagem nas duas telas."
          },
          {
            act: "end", icon: "",
            t: "Encerrar",
            d: "Desliga a TV e devolve o som ao notebook."
          }
        ]
      : shareStep === "profile"
        ? [
            {
              act: "work", icon: "",
              t: "Trabalho",
              d: "Espelha sem bordas, espaços e cantos arredondados."
            },
            {
              act: "chat", icon: "",
              t: "Resenha",
              d: "Espelha mantendo o visual atual."
            }
          ]
        : []

  readonly property string shareInfo: {
    if (shareMonitors.length === 0)
      return "";

    const m = shareMonitors[0];
    let s2 = m.name + " · " + m.width + "x" + m.height;

    if (m.mirrorOf && m.mirrorOf !== "none")
      s2 += " · espelhando";

    if (shareMonitors.length > 1)
      s2 += " (+" + (shareMonitors.length - 1) + ")";

    return s2;
  }

  function refreshShare() {
    shareChecking = true;
    shareProc.running = true;
  }

  function moveShare(delta) {
    const n = shareOpts.length;

    if (n === 0)
      return;

    shareSel = Math.max(0, Math.min(n - 1, shareSel + delta));
  }

  function shareChoose() {
    const o = shareOpts[shareSel];

    if (!o)
      return;

    // Encerrar funciona mesmo sem monitor detectado (para desfazer um estado antigo)
    if (shareStep === "mode" && o.act === "end") {
      shareEnd();
      return;
    }

    if (!shareHasExt)
      return;

    if (shareStep === "mode") {
      if (o.act === "mirror") {
        shareStep = "profile";
        shareSel = 0;
      } else {
        shareApply("extend", "");
      }
    } else if (shareStep === "profile") {
      shareApply("mirror", o.act);
    }
  }

  function shareBack() {
    if (shareStep === "profile") {
      shareStep = "mode";
      shareSel = 1;
    } else if (shareStep === "done") {
      shareStep = "mode";
      shareSel = 0;
    } else {
      phone.config.setKeep = true;
      phone.view = "settings";
    }
  }

  function shareApply(kind, profile) {
    const ext = shareMonitors[0];
    const inner = shareInternal;

    if (!ext)
      return;

    const luaBorderless =
      "hl.config({ general = { border_size = 0, gaps_in = 0, gaps_out = 0 }, decoration = { rounding = 0 } })";

    let luaMonitor = "";

    if (kind === "mirror") {
      luaMonitor =
        "hl.monitor({ output = \"" + ext.name + "\", mode = \"preferred\", position = \"0x0\", scale = 1, mirror = \"" + inner.name + "\" })";
    } else {
      const w = Math.round(inner.width / (inner.scale || 1));

      luaMonitor =
        "hl.monitor({ output = \"" + ext.name + "\", mode = \"preferred\", position = \"" + w + "x0\", scale = 1 })";
    }

    const wantBorderless = kind === "mirror" && profile === "work";
    const needReload = shareBorderless && !wantBorderless;

    // $1 = precisa de reload | $2 = tirar bordas | $3 = Lua das bordas | $4 = Lua do monitor
    Quickshell.execDetached(["sh", "-c", `
      if [ "$1" = "1" ]; then hyprctl reload; sleep 0.5; fi
      if [ "$2" = "1" ]; then hyprctl eval "$3"; fi
      hyprctl eval "$4"

      f="\${XDG_RUNTIME_DIR:-/tmp}/quickshell-share-audio"
      card=$(pactl list short cards | awk '{print $2}' | grep '^alsa_card' | head -n 1)

      if [ -n "$card" ]; then
        # guarda placa, perfil e sink originais (só se ainda não guardou)
        if [ ! -f "$f" ]; then
          prof=$(pactl list cards | awk -v c="$card" '$0 ~ ("Name: " c "$") {f=1} f && /Active Profile:/ {print $3; exit}')
          { echo "$card"; echo "$prof"; pactl get-default-sink; } > "$f"
        fi

        # ativa o perfil HDMI: sem ele o sink HDMI nem existe
        pactl set-card-profile "$card" output:hdmi-stereo 2>/dev/null

        hdmi=""
        i=0
        while [ $i -lt 20 ] && [ -z "$hdmi" ]; do
          hdmi=$(pactl list short sinks | awk '{print $2}' | grep -i hdmi | head -n 1)
          [ -n "$hdmi" ] || sleep 0.25
          i=$((i + 1))
        done

        if [ -n "$hdmi" ]; then
          pactl set-default-sink "$hdmi"
          for id in $(pactl list short sink-inputs | awk '{print $1}'); do
            pactl move-sink-input "$id" "$hdmi"
          done
        else
          # TV não entregou áudio: desfaz o perfil para não deixar sem som
          prof_orig=$(sed -n 2p "$f" 2>/dev/null)
          [ -n "$prof_orig" ] && pactl set-card-profile "$card" "$prof_orig" 2>/dev/null
          rm -f "$f"
        fi
      fi
    `, "sh", needReload ? "1" : "0", wantBorderless ? "1" : "0", luaBorderless, luaMonitor]);

    shareBorderless = wantBorderless;

    if (kind === "mirror") {
      shareStatus =
        "Espelhando " + inner.name + " em " + ext.name
        + (wantBorderless ? " (Trabalho)" : " (Resenha)");
    } else {
      shareStatus = "Telas unidas: " + ext.name + " à direita de " + inner.name;
    }
    shareStatus += " · som na TV";

    shareStep = "done";
    shareRecheck.restart();
  }

  // desliga a TV, devolve o som ao notebook e volta o áudio do sink salvo
  function shareEnd() {
    const ext = shareMonitors[0];
    const extName = ext ? ext.name : "";
    const needReload = shareBorderless;
    const luaOff = extName !== ""
      ? "hl.monitor({ output = \"" + extName + "\", disabled = true })"
      : "";

    Quickshell.execDetached(["sh", "-c", `
      f="\${XDG_RUNTIME_DIR:-/tmp}/quickshell-share-audio"

      if [ -f "$f" ]; then
        card=$(sed -n 1p "$f")
        prof=$(sed -n 2p "$f")
        prev=$(sed -n 3p "$f")

        [ -n "$card" ] && [ -n "$prof" ] && pactl set-card-profile "$card" "$prof" 2>/dev/null

        i=0
        while [ $i -lt 20 ] && ! pactl list short sinks | awk '{print $2}' | grep -qx "$prev"; do
          sleep 0.25
          i=$((i + 1))
        done

        if [ -n "$prev" ]; then
          pactl set-default-sink "$prev"
          for id in $(pactl list short sink-inputs | awk '{print $1}'); do
            pactl move-sink-input "$id" "$prev"
          done
        fi
        rm -f "$f"
      fi

      if [ "$1" = "1" ]; then hyprctl reload; sleep 0.5; fi
      if [ -n "$2" ]; then hyprctl eval "$2"; fi
    `, "sh", needReload ? "1" : "0", luaOff]);

    shareBorderless = false;
    shareStatus = "Tela e som voltaram para o notebook";
    shareStep = "done";
    shareRecheck.restart();
  }

  function handleShareKey(e) {
    switch (e.key) {
    case Qt.Key_Escape:
    case Qt.Key_Backspace:
    case Qt.Key_Left:
      shareBack();
      break;

    case Qt.Key_Up:    moveShare(-1); break;
    case Qt.Key_Down:  moveShare(1);  break;

    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Right:
      shareChoose();
      break;

    case Qt.Key_F5:
      refreshShare();
      break;

    default:
      return;
    }

    e.accepted = true;
  }

  readonly property string softLeftText: "Atualizar"

  readonly property string softCenterText:
    (shareStep === "done" || !shareHasExt) ? "" : "Escolher"

  readonly property string softRightText: "Voltar"

  function handleKey(e) {
    handleShareKey(e);
  }

  function softLeft() {
    refreshShare();
  }

  function softCenter() {
    shareChoose();
  }

  function softRight() {
    shareBack();
  }

  // relê os monitores logo depois de aplicar (pra mostrar o estado real)
  Timer {
    id: shareRecheck

    interval: 1200
    repeat: false

    onTriggered: refreshShare()
  }

  Process {
    id: shareProc

    running: false
    command: ["hyprctl", "monitors", "all", "-j"]

    stdout: StdioCollector {
      onStreamFinished: {
        let arr = [];

        try {
          arr = JSON.parse(text);
        } catch (err) {
          arr = [];
        }

        const isInternal = function (n) {
          return /^(eDP|LVDS|DSI)/i.test(n || "");
        };

        const ext = [];
        let inner = null;

        for (let i = 0; i < arr.length; i++) {
          if (isInternal(arr[i].name)) {
            if (!inner)
              inner = arr[i];
          } else {
            ext.push(arr[i]);
          }
        }

        phone.share.shareInternal =
          inner || { name: "eDP-1", width: 1366, scale: 1 };

        phone.share.shareMonitors = ext;
        phone.share.shareChecking = false;

        if (phone.share.shareSel >= phone.share.shareOpts.length)
          phone.share.shareSel = 0;
      }
    }
  }
}
