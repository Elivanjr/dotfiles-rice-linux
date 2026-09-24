
//@ pragma UseQApplication
//Obs: isso foi vibecodado, entao até eu entender como o Quickshell funciona, não use isso. Ou use se for maluco...
//
// Instalação:
//   mkdir -p ~/.config/quickshell/topbar
//   cp shell.qml ~/.config/quickshell/topbar/
//   quickshell -c topbar
//
// Módulos replicados da waybar:
//   esquerda: custom/launcher, hyprland/window, hyprland/workspaces, custom/spotify
//   centro:   clock
//   direita:  tray, memory, cpu, network, pulseaudio, battery

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Networking

ShellRoot {
  id: root

  // ---------- paleta / config ----------
  // mapeamento de cores igual ao style.css da waybar do usuário:
  // fundo de módulo = @color15 (surface_container), texto = @source_color,
  // destaque = @color2/@foreground (primary) — todos opacos, sem alpha-blend.
  readonly property color colModBg: Colors.md3.surface_container
  readonly property color colText: Colors.md3.source_color
  readonly property color colMuted: Colors.md3.outline
  readonly property color colAccent: Colors.md3.primary
  readonly property int barHeight: 39
  // espaçamento igual ao style.css da waybar: 8px entre módulos, 6px de
  // respiro no topo/embaixo da barra
  readonly property int moduleSpacing: 8
  readonly property int barMargin: 6
  // fonte usada em todos os módulos (texto e ícones)
  readonly property string nerdFont: "JetBrainsMono NF"
  // controla se a barra está visível — alternado via IPC
  property bool barVisible: true

  // ---------- IPC: permite esconder/mostrar a barra via keybind do Hyprland ----------
  IpcHandler {
    target: "topbar"

    function toggle(): void {
      root.barVisible = !root.barVisible;
    }

    function show(): void {
      root.barVisible = true;
    }

    function hide(): void {
      root.barVisible = false;
    }
  }

  // abre/fecha o painel de clipboard — alternado via IPC
  // uso: quickshell -c topbar ipc call clipboard toggle
  property bool clipboardPanelOpen: false

  IpcHandler {
    target: "clipboard"

    function toggle(): void {
      root.clipboardPanelOpen = !root.clipboardPanelOpen;
    }

    function show(): void {
      root.clipboardPanelOpen = true;
    }

    function hide(): void {
      root.clipboardPanelOpen = false;
    }
  }

  // ---------- pequeno componente reutilizável: a "pílula" ----------
  component Pill: Rectangle {
    id: pill

    color: root.colModBg
    radius: 10
    height: root.barHeight
    implicitWidth: rowLayout.implicitWidth + 20

    default property alias content: rowLayout.children

    property alias spacing: rowLayout.spacing
    property bool mouseEnabled: true

    signal clicked(var mouse)
    signal wheel(var wheel)

    RowLayout {
      id: rowLayout

      anchors.centerIn: parent
      spacing: 6
    }

    MouseArea {
      anchors.fill: parent
      enabled: pill.mouseEnabled
      acceptedButtons: Qt.LeftButton | Qt.RightButton

      onClicked: (mouse) => pill.clicked(mouse)
      onWheel: (wheel) => pill.wheel(wheel)
    }
  }

  // ---------- texto padrão ----------
  component ModText: Text {
    font.family: root.nerdFont
    font.pixelSize: 12
  }

  // =====================================================================
  // SERVIÇOS DE FUNDO
  // =====================================================================

  // ---------- relógio ----------
  QtObject {
    id: clock

    property string text: ""
    property string timeText: ""
    property string dateText: ""

    readonly property var weekdays: [
      "Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira",
      "Quinta-feira", "Sexta-feira", "Sábado"
    ]
    readonly property var months: [
      "Janeiro",
      "Fevereiro",
      "Março",
      "Abril",
      "Maio",
      "Junho",
      "Julho",
      "Agosto",
      "Setembro",
      "Outubro",
      "Novembro",
      "Dezembro"
    ]
    readonly property var monthsShort: [
      "Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
      "Jul", "Ago", "Set", "Out", "Nov", "Dez"
    ]
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true

    onTriggered: {
      const now = new Date();
      const dd = String(now.getDate()).padStart(2, "0");
      const hh = String(now.getHours()).padStart(2, "0");
      const mm = String(now.getMinutes()).padStart(2, "0");
      const ss = String(now.getSeconds()).padStart(2, "0");

      clock.text =
        dd + " " +
        clock.monthsShort[now.getMonth()] +
        " • " +
        hh + ":" +
        mm;

      clock.timeText = hh + ":" + mm + ":" + ss;
      clock.dateText = clock.weekdays[now.getDay()] + ", " + dd + " de " + clock.months[now.getMonth()];
    }
  }

  // ---------- clima: Open-Meteo (sem precisar de chave de API) ----------
  // TROCAR AQUI: coloca a latitude/longitude do seu local
  readonly property real weatherLat: -15.460694 // <-- TROCAR (latitude) -15.460694, -44.364737
  readonly property real weatherLon: -44.364737 // <-- TROCAR (longitude)

  QtObject {
    id: weatherState
    property real tempC: NaN
    property real rainProbability: NaN
  }
  Process {
    id: weatherProc
    command: ["bash", "-c",
      "curl -s 'https://api.open-meteo.com/v1/forecast?latitude=" + root.weatherLat +
      "&longitude=" + root.weatherLon +
      "&current=temperature_2m,weather_code&hourly=precipitation_probability'"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(this.text);
          weatherState.tempC = data.current.temperature_2m;

          const currentHour = data.current.time.slice(0, 13);
          const hourlyIndex = data.hourly.time.findIndex(
            (time) => time.slice(0, 13) === currentHour
          );

          if (hourlyIndex !== -1) {
            weatherState.rainProbability =
              data.hourly.precipitation_probability[hourlyIndex];
          }
        } catch (e) {
          // rede fora do ar / sem resposta — mantém o último valor válido
        }
      }
    }
  }
  Timer {
    // clima não muda rápido — 30 min evita bater na API à toa
    interval: 10 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: weatherProc.running = true
  }

  // ---------- notificações: NotificationCenter nativo (substitui SwayNC) ----------
  // abre/fecha ao clicar no relógio
  property bool notifCenterOpen: false

  // ---------- MPRIS: Spotify tem prioridade, mpv como fallback ----------
  readonly property var spotifyPlayer: {
    for (const p of Mpris.players.values) {
      if (
        (p.identity || "")
          .toLowerCase()
          .indexOf("spotify") !== -1
      ) {
        return p;
      }
    }

    return null;
  }

  readonly property var mpvPlayer: {
    for (const p of Mpris.players.values) {
      if (
        (p.identity || "")
          .toLowerCase()
          .indexOf("mpv") !== -1
      ) {
        return p;
      }
    }

    return null;
  }

  readonly property var mediaPlayer:
    root.spotifyPlayer || root.mpvPlayer

  readonly property bool mediaIsMpv:
    !root.spotifyPlayer && root.mpvPlayer !== null

  // ---------- notificação especial "tocando agora" (só Spotify) ----------
  // dispara sempre que artista+título mudam (troca de faixa real, ou a
  // primeira detecção do player). Nunca aparece na central de notificações
  // — é gerada aqui, não é uma notificação D-Bus de verdade. Só observa
  // root.spotifyPlayer — mpv não entra nessa, mesmo se estiver tocando.
  //
  // debounce: quando o Spotify abre, os metadados (artista/título) chegam
  // em etapas separadas (título vazio primeiro, depois preenchido aos
  // poucos) — cada mudança de currentTrackKey reiniciava o disparo, dando
  // notificação duplicada (uma vazia + uma certa). O Timer só dispara
  // depois que o valor fica parado por um tempinho sem mudar de novo.
  readonly property string currentTrackKey:
    root.spotifyPlayer
      ? ((root.spotifyPlayer.trackArtist || "") + " - " + (root.spotifyPlayer.trackTitle || ""))
      : ""

  onCurrentTrackKeyChanged: mediaToastDebounce.restart()

  Timer {
    id: mediaToastDebounce
    interval: 400
    onTriggered: {
      if (root.spotifyPlayer && (root.spotifyPlayer.trackTitle || "") !== "") {
        NotificationService.pushMediaToast(
          root.spotifyPlayer.trackTitle || "",
          root.spotifyPlayer.trackArtist || "",
          root.spotifyPlayer.trackArtUrl || ""
        );
      }
    }
  }

  // ---------- hyprland/window ----------
  readonly property var windowRewrite: ({
    "^$": " Desktop",

    "^brave-origin$": "󰖟 Brave",
    "^brave-lodlkdfmihgonocnmddehnfgiljnadcf-Default$": " Twitter",
    "^brave-agimnkijcaahngcdmfeangaknmldooml-Default$": " YouTube",
    "^brave-eolojifegfdgeabmkemdoiojfffjoabd-Default$": "󱨎 Cajuí",
    "^brave-cadlkienfkclaiaibeoongdcgmdikeeg-Default$": " ChatGPT",
    "^brave-fmpnliohjhemenmnlpbfagaolkdacoja-Default$": " Claude",
    "^brave-akpamiohjfcnimfljfndmaldlcfphjmp-Default$": "󰋾 Instagram",
    "^brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default$": " WhatsApp",
    "^brave-mjoklplbddabcmpepnokjaffbmgbkkgg-Default$": " GitHub",
    "^brave-kjcjfjccmpngedeildfijeanhihmolck-Default$": "󰋀 Classroom",
    "^brave-gkpgichlplhgcfedjgdpjophefobmgag-Default$": " MyAnimeList",

    "^Spotify$": " Spotify",
    "^discord$": "  Discord",
    "^steam$": " Steam",

    "^(VSCodium|codium)$": " VSCodium",
    "^(Code|code)$": " VSCode",
    "^(antigravity-ide)$": " Antigravity",

    "^(gnome-terminal|org.gnome.Terminal|kitty|Alacritty)$": " Terminal",

    "^DBeaver$": " DBeaver",
    "^com\\.interversehq\\.qView$": " qView",
    "^net\\.lutris\\.Lutris$": " Lutris",

    "^steam_app_3224770$": " Umamusume: Pretty Derby",
    "^steam_app_2076010$": " UNDER NIGHT IN-BIRTH II Sys:Celes",
    "^steam_app_1451940$": " NEEDY GIRL OVERDOSE",
    "^steam_app_413150$": " Stardew Valley",
    "^steam_app_1030300$": " Hollow Knight: Silksong",
    "^steam_app_367520$": " Hollow Knight",
    "^steam_app_1262600$": " Need for Speed Rivals",
    "^steam_app_940910$": " Minoria",

    "^teamspeak-client$": " Teamspeak",
    "^blueman-manager$": " Config. Bluetooth",
    "^(io.github.airctl)$": "  Config. Wifi",
    "^(org.telegram.desktop)$": " Telegram",

    "^(org.gnome.seahorse.Application)$": "󰢬 Seahorse",
    "^(nemo)$": " Nemo",
    "^(org.gnome.Nautilus)$": " Arquivos",
    "^(org.kde.kdenlive)$": " Kdenlive",
    "^(md.obsidian.Obsidian)$": " Obsidian",

    "^waypaper$": "󰸉 Waypaper",
    "^(com.obsproject.Studio)$": "󰟞 OBS Studio",
    "^hyprland-share-picker$": " Config. Transmitir",
    "^geany$": "󰼙 Geany",

    "^mpv$": "󰨜 mpv",
    "^vlc$": "󰕼 VLC",
    "^audacity$": "󰋋 Audacity",
    "^gimp$": " GIMP",
    "^transmission-qt$": " Transmission",

    "^speed.exe$": "  NFS: Most Wanted",
    "^speed2.exe$": "  NFS: Underground 2",

    "^PPSSPPSDL$": "󰊖 PPSSPP",
    "^xdg-desktop-portal-gtk$": "󰏓 Abrir/Salvar",
    "^firefox$": " Firefox",

    "^libreoffice-writer$": " Libreoffice Writer",
    "^libreoffice-calc$": " Libreoffice Calc",
    "^libreoffice-impress$": " Libreoffice Impress",
    "^libreoffice-math$": " Libreoffice Math",
    "^libreoffice-base$": " Libreoffice Base",
    "^libreoffice-draw$": " Libreoffice Draw",
    "^libreoffice-startcenter$": " Libreoffice",

    "^nwg-look$": " GTK Settings",
    "^python3$": "󱛿 OpenShot",
    "^org.cutwire.Drift$": "󱛿 Drift",
    "^org.pulseaudio.pavucontrol$": " Volume",
    "^org.pwmt.zathura$": " Zathura",
    "^com.usebottles.bottles$": "󰡶 Garrafas",
    "^io.missioncenter.MissionCenter$": " Tarefas",
    "^CoppeliaSim$": "  CoppeliaSim",
    "^kopuz$": "󰝚 Kopuz",
    "^org.yuzu_emu.yuzu$": " Yuzu",
    "^blueman-sendto$": " Enviar",
    "^brave-lgnggepjiihbfdbedefdhcffnmhcahbm-Default$": " Reddit",
    "^com.heroicgameslauncher.hgl$": "󱢿 Heroic",
    "^brave-aghbiahbpaijignceidepookljebhfak-Default$": " Google Drive"
  })

  function windowLabel() {
    const top = Hyprland.activeToplevel;
    const cls = (top && top.wayland)
      ? (top.wayland.appId || "")
      : "";

    for (const pattern in root.windowRewrite) {
      if (new RegExp(pattern).test(cls)) {
        return root.windowRewrite[pattern];
      }
    }

    return cls || " Desktop";
  }

  // ---------- CPU ----------
  QtObject {
    id: cpuState

    property real usage: 0
    property real _prevIdle: -1
    property real _prevTotal: -1
  }

  Process {
    id: cpuProc

    command: ["cat", "/proc/stat"]

    stdout: StdioCollector {
      onStreamFinished: {
        const line = this.text.split("\n")[0];

        const parts =
          line
            .trim()
            .split(/\s+/)
            .slice(1)
            .map(Number);

        const idle = parts[3] + parts[4];
        const total = parts.reduce((a, b) => a + b, 0);

        if (cpuState._prevTotal >= 0) {
          const idleDelta = idle - cpuState._prevIdle;
          const totalDelta = total - cpuState._prevTotal;

          cpuState.usage =
            totalDelta > 0
              ? Math.round(100 * (1 - idleDelta / totalDelta))
              : 0;
        }

        cpuState._prevIdle = idle;
        cpuState._prevTotal = total;
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true

    onTriggered: cpuProc.running = true
  }

  // ---------- memória ----------
  QtObject {
    id: memState

    property real usedGb: 0
  }

  Process {
    id: memProc

    command: ["cat", "/proc/meminfo"]

    stdout: StdioCollector {
      onStreamFinished: {
        const text = this.text;

        const total =
          parseInt(/MemTotal:\s+(\d+)/.exec(text)[1]);

        const avail =
          parseInt(/MemAvailable:\s+(\d+)/.exec(text)[1]);

        memState.usedGb =
          Math.round(
            ((total - avail) / 1024 / 1024) * 10
          ) / 10;
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true

    onTriggered: memProc.running = true
  }

  // ---------- rede ----------
  readonly property var activeDevice: {
    for (const d of Networking.devices.values) {
      if (d.connected) {
        return d;
      }
    }

    return null;
  }

  readonly property var activeWifiNetwork: {
    if (
      !root.activeDevice ||
      root.activeDevice.type !== DeviceType.Wifi
    ) {
      return null;
    }

    for (const n of root.activeDevice.networks.values) {
      if (n.connected) {
        return n;
      }
    }

    return null;
  }

  // ---------- pipewire ----------
  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  readonly property var sink:
    Pipewire.defaultAudioSink

  readonly property real volumePct:
    (root.sink &&
     root.sink.ready &&
     root.sink.audio)
      ? Math.round(root.sink.audio.volume * 100)
      : 0

  readonly property bool muted:
    (root.sink &&
     root.sink.ready &&
     root.sink.audio)
      ? root.sink.audio.muted
      : false

  function changeVolume(delta) {
    if (
      root.sink &&
      root.sink.ready &&
      root.sink.audio
    ) {
      let v = root.sink.audio.volume + delta;

      v = Math.max(0, Math.min(1.5, v));

      root.sink.audio.volume = v;
    }
  }

  function toggleMute() {
    if (
      root.sink &&
      root.sink.ready &&
      root.sink.audio
    ) {
      root.sink.audio.muted =
        !root.sink.audio.muted;
    }
  }

  // ---------- bateria ----------
  readonly property var battery:
    UPower.displayDevice

  // =====================================================================
  // UMA BARRA POR MONITOR
  // =====================================================================

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panelWindow

      required property var modelData

      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight:
        root.barHeight + root.barMargin * 2

      color: "transparent"

      visible: root.barVisible

      // ===================== GRUPO ESQUERDO =====================

      RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: root.moduleSpacing
        anchors.verticalCenter: parent.verticalCenter

        spacing: root.moduleSpacing

        // ---- custom/launcher ----

        Pill {
          ModText {
            text: ""
            color: root.colText
            font.pixelSize: 24
          }

          onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
              launcherOpen.running = true;
            } else {
              launcherKill.running = true;
            }
          }
        }

        Process {
          id: launcherOpen
          command: [
            "bash",
            "-c",
            "~/.config/rofi/runner.sh"
          ]
        }

        Process {
          id: launcherKill
          command: ["pkill", "rofi"]
        }

        // ---- hyprland/window ----

        Pill {
          ModText {
            text: root.windowLabel()
            color: root.colText
            elide: Text.ElideRight

            Layout.maximumWidth: 260
          }
        }

        // ---- hyprland/workspaces (ícones antigos da waybar, por número) ----
        Pill {
          id: wsPill
          mouseEnabled: false // deixa cada ícone receber o próprio clique

          // codepoints exatos tirados do format-icons da waybar do usuário
          readonly property var wsIcons: ({
            "1": " ",
            "2": " ",
            "3": " ",
            "4": " ",
            "5": " ",
            "6": " ",
            "7": " ",
            "8": " ",
            "9": " ",
            "10": " "
          })

          Repeater {
            // workspaces especiais (scratchpad etc.) têm name "special:..." —
            // não tem property "isSpecial" pronta na API do Quickshell 0.3.1,
            // então filtra pelo nome, que é a convenção real do Hyprland
            model: Hyprland.workspaces.values.filter(w => !w.name.startsWith("special"))
            ModText {
              required property var modelData
              Layout.alignment: Qt.AlignVCenter
              text: wsPill.wsIcons[String(modelData.id)] || String(modelData.id)
              color: modelData.active ? root.colAccent : root.colMuted

              MouseArea {
                anchors.fill: parent
                onClicked: modelData.activate()
              }
            }
          }
        }


        // ---- custom/spotify ----

        Pill {
          id: mediaPill
          visible:
            root.mediaPlayer !== null

          ModText {
            text:
              root.mediaIsMpv
                ? "󰝚"
                : "󰓇"

            color: root.colAccent
          }

          Item {
            id: mediaMarquee

            property string mediaText:
              root.mediaPlayer
                ? (
                    (root.mediaPlayer.trackArtist || "") +
                    " - " +
                    (root.mediaPlayer.trackTitle || "")
                  )
                : ""

            readonly property bool needsMarquee:
              mediaText.length > 0 &&
              mediaTextItem.implicitWidth > width

            Layout.preferredWidth: 180
            Layout.minimumWidth: 180
            Layout.maximumWidth: 180
            Layout.preferredHeight: 20

            clip: true

            Timer {
              id: marqueeDelay
              interval: 1500
              repeat: false

              onTriggered: {
                if (mediaMarquee.needsMarquee) {
                  marqueeAnimation.start();
                }
              }
            }

            ModText {
              id: mediaTextItem

              text: mediaMarquee.mediaText
              color: root.colText

              x: 0
              anchors.verticalCenter: parent.verticalCenter
              width: implicitWidth
              height: implicitHeight

              SequentialAnimation {
                id: marqueeAnimation

                loops: Animation.Infinite

                PauseAnimation {
                  duration: 300
                }

                NumberAnimation {
                  target: mediaTextItem
                  property: "x"
                  from: 0
                  to: -mediaTextItem.implicitWidth
                  duration: Math.max(
                    5000,
                    mediaTextItem.implicitWidth * 35
                  )
                  easing.type: Easing.Linear
                }

                PauseAnimation {
                  duration: 500
                }

                PropertyAction {
                  target: mediaTextItem
                  property: "x"
                  value: 0
                }
              }

              onTextChanged: {
                marqueeAnimation.stop();
                marqueeDelay.stop();
                x = 0;

                if (mediaMarquee.needsMarquee) {
                  marqueeDelay.start();
                }
              }
            }

            Component.onCompleted: {
              if (mediaMarquee.needsMarquee) {
                marqueeDelay.start();
              }
            }
          }

          onClicked: (mouse) => {
            if (!root.mediaPlayer) return;
            if (mouse.button === Qt.LeftButton) root.mediaPlayer.pause();
            else root.mediaPlayer.play();
          }
        }
      }

      // ===================== GRUPO CENTRAL =====================

      Pill {
        anchors.horizontalCenter:
          parent.horizontalCenter

        anchors.verticalCenter:
          parent.verticalCenter

        ModText {
          text: clock.text +
            " • " +
            (isNaN(weatherState.tempC) ? "--°C" : Math.round(weatherState.tempC) + "°C") +
            " · " +
            (isNaN(weatherState.rainProbability) ? "--%" : Math.round(weatherState.rainProbability) + "%") +
            " 🌧"
          color: root.colText
        }

        onClicked:
          root.notifCenterOpen = !root.notifCenterOpen
      }

      // ===================== GRUPO DIREITO =====================

      RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: root.moduleSpacing
        anchors.verticalCenter: parent.verticalCenter

        spacing: root.moduleSpacing

        // ---- tray ----

        Pill {
          visible:
            SystemTray.items.values.length > 0

          mouseEnabled: false
          spacing: 10

          Repeater {
            model: SystemTray.items.values

            Image {
              required property var modelData

              Layout.preferredWidth: 14
              Layout.preferredHeight: 14

              source: modelData.icon

              MouseArea {
                anchors.fill: parent

                acceptedButtons:
                  Qt.LeftButton | Qt.RightButton

                onClicked: (mouse) => {
                  if (mouse.button === Qt.LeftButton) {
                    modelData.activate();
                  } else if (modelData.hasMenu) {
                    const pos =
                      mapToItem(
                        null,
                        mouse.x,
                        mouse.y
                      );

                    modelData.display(
                      panelWindow,
                      pos.x,
                      pos.y
                    );
                  }
                }
              }
            }
          }
        }

        // ---- memory ----

        Pill {
          ModText {
            text: "󰾆"
            color: root.colText
          }

          ModText {
            text:
              memState.usedGb + "GB"

            color: root.colText
          }
        }

        // ---- cpu ----

        Pill {
          ModText {
            text: "󰍛"
            color: root.colText
          }

          ModText {
            text:
              cpuState.usage + "%"

            color: root.colText
          }
        }

        // ---- network ----

        Pill {
          id: networkPill
          property bool expanded: false

          onClicked:
            networkPill.expanded = !networkPill.expanded

          ModText {
            text: {
              if (
                root.activeDevice &&
                root.activeDevice.type ===
                  DeviceType.Wired
              ) {
                return "󰈀";
              }

              if (root.activeWifiNetwork) {
                return "";
              }

              return "󰖪";
            }

            color:
              root.activeDevice
                ? root.colText
                : root.colMuted
          }

          ModText {
            visible: networkPill.expanded

            text: {
              if (!root.activeDevice) {
                return "Desconectado";
              }

              if (
                root.activeDevice.type ===
                  DeviceType.Wired
              ) {
                return "Conexão a cabo";
              }

              if (root.activeWifiNetwork) {
                return root.activeWifiNetwork.name;
              }

              return "Sem rede";
            }

            color: root.colText
            elide: Text.ElideRight

            Layout.maximumWidth: 220
          }
        }

        Pill {
          ModText {
            text: {
              if (root.muted) {
                return "\u{F0581}"; // volume_off
              }

              if (root.volumePct <= 25) {
                return "\u{F0580}"; // volume_low
              }

              if (root.volumePct <= 50) {
                return "\u{F057F}"; // volume_medium
              }

              if (root.volumePct <= 75) {
                return "\u{F057E}"; // volume_high
              }

              return "\u{F057E}"; // sem um 4º glifo "bem alto" confirmado — reaproveitei volume_high
            }

            color:
              root.muted
                ? root.colMuted
                : root.colText

            font.pixelSize: 13
          }

          ModText {
            visible: !root.muted

            text: root.volumePct + "%"

            color: root.colText
          }

          onClicked:
            root.toggleMute()

          onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
              root.changeVolume(0.01);
            } else {
              root.changeVolume(-0.01);
            }
          }
        }
        // ---- battery ----

        Pill {
          ModText {
            text: {
              if (
                root.battery.state ===
                  UPowerDeviceState.Charging
              ) {
                return "";
              }

              if (root.battery.percentage >= 1.0) {
                return "󰌪";
              }

              if (root.battery.percentage >= 0.89) {
                return "󰂂";
              }

              if (root.battery.percentage >= 0.78) {
                return "󰂁";
              }

              if (root.battery.percentage >= 0.67) {
                return "󰂀";
              }

              if (root.battery.percentage >= 0.56) {
                return "󰁿";
              }

              if (root.battery.percentage >= 0.45) {
                return "󰁾";
              }

              if (root.battery.percentage >= 0.34) {
                return "󰁽";
              }

              if (root.battery.percentage >= 0.23) {
                return "󰁼";
              }

              if (root.battery.percentage >= 0.12) {
                return "󰁻";
              }

              return "󰁺";
            }

            color: root.colText
          }

          ModText {
            text:
              Math.round(
                root.battery.percentage * 100
              ) + "%"

            color: root.colText
          }
        }
      }
    }
  }

  // ---------- ClipboardPanel (aberto/fechado via IPC — ver keybind no Hyprland) ----------
  Variants {
    model: Quickshell.screens

    ClipboardPanel {
      required property var modelData
      screenRef: modelData
      panelOpen: root.clipboardPanelOpen
      onCloseRequested: root.clipboardPanelOpen = false
    }
  }

  // ---------- NotificationCenter (aberto/fechado pelo clique no relógio) ----------
  Variants {
    model: Quickshell.screens

    NotificationCenter {
      required property var modelData
      screenRef: modelData
      panelOpen: root.notifCenterOpen
      onCloseRequested: root.notifCenterOpen = false
    }
  }

  // ---------- NotificationToasts (sempre ativo, sem toggle — some sozinho) ----------
  Variants {
    model: Quickshell.screens

    NotificationToasts {
      required property var modelData
      screenRef: modelData
    }
  }
}

