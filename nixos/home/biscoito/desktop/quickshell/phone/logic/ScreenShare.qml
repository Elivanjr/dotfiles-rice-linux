// logic/ScreenShare.qml — Compartilhar tela: unir/espelhar monitor externo (hyprctl eval)
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
            d: "Estende a área de trabalho para a tela externa."
          },
          {
            act: "mirror", icon: "mirror",
            t: "Espelhar tela",
            d: "Mostra a mesma imagem nas duas telas."
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
    if (!shareHasExt)
      return;

    const o = shareOpts[shareSel];

    if (!o)
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
    `, "sh", needReload ? "1" : "0", wantBorderless ? "1" : "0", luaBorderless, luaMonitor]);

    shareBorderless = wantBorderless;

    if (kind === "mirror") {
      shareStatus =
        "Espelhando " + inner.name + " em " + ext.name
        + (wantBorderless ? " (Trabalho)" : " (Resenha)");
    } else {
      shareStatus = "Telas unidas: " + ext.name + " à direita de " + inner.name;
    }

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
