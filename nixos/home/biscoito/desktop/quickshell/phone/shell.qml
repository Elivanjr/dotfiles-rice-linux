// phone/shell.qml — celular vermelho (modelo do Figma) como shell próprio
//
// ESTRUTURA (modularizada):
//   shell.qml     janela, geometria, tema, IPC e composição
//   logic/*.qml   um módulo de lógica por recurso (sem visual)
//   views/*.qml   uma tela por arquivo (Menu, Música, SSH, IA...)
//   ui/*.qml      peças compartilhadas (ViewBase, Glyph, barra de status, softkeys...)
//   Veja ARQUITETURA.md
//
// Instalação:
//   ~/.config/quickshell/phone/shell.qml
//   ~/.config/quickshell/phone/assets/phone.png
//
// Rodar:   qs -c phone
// Abrir:   qs -c phone ipc call phone toggle     (também: open / close)
// Hyprland: bind = SUPER, P, exec, qs -c phone ipc call phone toggle
//
// Aparece deslizando de baixo, colado no canto inferior direito, com a
// parte de baixo (teclado) escondida pela borda da tela.
//
// TELA
//   Menu   : grade 4x4 com os apps do sistema (DesktopEntries).
//            O nome do app selecionado aparece em rosa no topo.
//            Digitar filtra | setas movem | Enter abre | Esc limpa/fecha
//   Música : player MPRIS (primeiro item da grade).
//   Wallpaper : galeria da pasta de wallpapers; clicar aplica com
//               waypaper --wallpaper <arquivo>
//   Meus arquivos : navegador de pastas (começa na home); pasta entra,
//               arquivo abre com xdg-open
//   Compartilhar tela : detecta monitor externo (HDMI/VGA/DP...) e deixa
//               escolher Unir ou Espelhar (Trabalho / Resenha), via
//               hyprctl eval (Lua do Hyprland)
//   SSH : túnel CachyOS → Termux (ssh -L, chave ~/.ssh/termux_maya, sem senha) +
//         navegador de pastas + mini terminal, com baixar/enviar arquivos (scp).
//         O IP do Termux é digitado na tela (muda conforme o Wi-Fi)
//   IA  : conversa com modelos do Ollama (streaming, Markdown, blocos de código,
//         anexos de imagem/texto). Usa scripts/ai/ai-chat.sh e ai-attach.sh
//   Configurações: Wi-Fi (e ponto de acesso), Bluetooth, Bateria (modos de energia),
//         Temas (claro/escuro só no celular), Telas (+ compartilhar tela), Local,
//         Idioma e Teclado, Sobre o Notebook. Salva em ~/.local/state/quickshell-phone
//   Calculadora: + − × ÷ ^ % e parênteses; teclado do PC, D-pad ou mouse
//   Agendar: agenda comandos com o `at` (lista, cria e remove jobs; atd já ativo)
//   Clipboard: histórico do cliphist (busca, miniaturas de imagem, copiar de volta)
//   Baixar: vídeo ou áudio com o yt-dlp (link -> qualidade -> progresso), em Vídeos/Música
//   Softkeys: Opções / Selecionar / Voltar (clicáveis)
//
// CORPO
//   botões laterais : anterior | play/pause | próxima
//   botões de metal : ✉ Discord | ⓘ info do sistema | 📖 PDFCraft
//                     📷 print da tela (grim - | wl-copy)


import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

import "logic"
import "views"
import "ui"

PanelWindow {
  id: root

  property bool panelOpen: false

  // "menu", "music", "wall", "files", "foco", "share", "ssh", "ai", "settings",
  // "calc", "term", "sched", "dl", "clip", "snake", "info"
  property string view: "menu"

  // relativo a este arquivo (não depende de onde o qs foi chamado)
  property url bodySource: Qt.resolvedUrl("assets/phone.png")

  // distância da borda direita da tela
  property int edgeMargin: 2

  // botão 📖
  property string pdfApp:
    Quickshell.env("HOME") + "/Applications/pdfcraft-0.11.0-linux-x86_64.AppImage"

  // foto de perfil (AccountsService)
  property string photoSource:
    "file:///var/lib/AccountsService/icons/" + Quickshell.env("USER")

  // wallpaper do celular (fundo da tela de vidro, atrás dos apps)
  property string celularBg:
    Quickshell.env("HOME") + "/Imagens/hyprlandWallpapers/celularbg.png"

  // opacidade do véu preto entre o wallpaper e os ícones (0 = nenhum, 1 = preto)
  property real wallDim: 0.55

  // true = wallpaper só no menu de apps; false = em todas as telas
  property bool wallOnlyMenu: false

  // ================================================================
  // GEOMETRIA (px do PNG do Figma: 424x904)
  // ================================================================

  readonly property real ps: 1.12

  // recorte visível, em px do PNG
  readonly property real cropL: 15

  readonly property real cropR: 405

  readonly property real cropT: 4

  readonly property real cropB: 652

  function s(v) { return v * ps; }

  function fx(v) { return (v - cropL) * ps; }

  function fy(v) { return (v - cropT) * ps; }

  // tela de vidro (px do PNG)
  readonly property real lcdX: 72

  readonly property real lcdY: 97

  readonly property real lcdW: 280

  readonly property real lcdH: 327

  // tela de vidro (usada pela ViewBase)
  readonly property Item lcdItem: lcd

  // ================================================================
  // JANELA
  // ================================================================

  anchors {
    right: true
    bottom: true
  }

  margins {
    right: root.edgeMargin
  }

  implicitWidth: Math.round((cropR - cropL) * ps)

  implicitHeight: Math.round((cropB - cropT) * ps)

  color: "transparent"

  exclusiveZone: 0

  WlrLayershell.layer: WlrLayer.Overlay

  WlrLayershell.namespace: "quickshell:phone"

  // nas telas com teclado (menu, apps, player) a janela captura o teclado;
  // só "info" fica sem foco
  WlrLayershell.keyboardFocus:
    panelOpen && (view === "menu" || view === "wall" || view === "files" || view === "foco" || view === "share" || view === "ssh" || view === "ai" || view === "settings" || view === "calc" || view === "term" || view === "music" || view === "sched" || view === "dl" || view === "clip" || view === "snake")
      ? WlrKeyboardFocus.Exclusive
      : WlrKeyboardFocus.None

  property real shown: panelOpen ? 1 : 0

  Behavior on shown {
    NumberAnimation {
      duration: 300
      easing.type: Easing.OutCubic
    }
  }

  visible: shown > 0.001

  mask: Region { item: stage }

  onPanelOpenChanged: {
    menu.optionsOpen = false;
    ssh.sshOptOpen = false;
    ai.aiOptOpen = false;
    files.filesPick = false;
    files.filesPickUpload = false;
    files.filesPickAi = false;
    files.filesReturnView = "menu";

    if (panelOpen) {
      view = "menu";
      menu.query = "";
      menu.selected = 0;
      keyCatcher.forceActiveFocus();
    }
  }

  onViewChanged: {
    menu.optionsOpen = false;

    if (view === "menu" || view === "wall" || view === "files" || view === "foco" || view === "share" || view === "ssh" || view === "ai" || view === "settings" || view === "calc" || view === "term" || view === "music" || view === "sched" || view === "dl" || view === "clip" || view === "snake")
      keyCatcher.forceActiveFocus();

    if (view === "settings")
      config.setEnter();

    if (view === "ssh")
      ssh.sshEnter();

    if (view === "ai")
      ai.aiEnter();

    if (view === "term")
      term.termEnter();

    if (view === "sched")
      sched.schedEnter();

    if (view === "clip")
      clip.clipEnter();

    if (view === "snake")
      snake.snakeEnter();

    if (view === "info")
      info.refreshInfo();

    if (view === "wall")
      walls.refreshWalls();

    if (view === "files")
      files.listDir(files.filesDir);

    if (view === "share") {
      share.shareStep = "mode";
      share.shareSel = 0;
      share.shareStatus = "";
      share.refreshShare();
    }
  }

  IpcHandler {
    target: "phone"

    function toggle(): void {
      root.panelOpen = !root.panelOpen;
    }

    function open(): void {
      root.panelOpen = true;
    }

    function close(): void {
      root.panelOpen = false;
    }

    // lista todos os apps: ESCONDIDO / visível, id e nome
    function apps(): string {
      const list = DesktopEntries.applications.values;
      const rows = [];

      for (let i = 0; i < list.length; i++) {
        const e = list[i];

        if (e.noDisplay)
          continue;

        rows.push(
          (root.menu.isHiddenApp(e, true) ? "ESCONDIDO  " : "visível    ")
          + e.id + "  |  " + e.name
        );
      }

      rows.sort();

      return rows.join("\n");
    }
  }

  // ================================================================
  // PALETA / FONTES DA TELA (tiradas do Figma)
  // ================================================================

  readonly property string fontUi: "Inter"

  readonly property string fontMono: "monospace"

  // tema do celular (só os widgets daqui; não mexe no tema do sistema).
  // Alternado em Configurações > Temas e salvo em disco.
  property bool themeDark: true

  // branco translúcido no escuro, preto translúcido no claro
  function ov(a) {
    return themeDark ? Qt.rgba(1, 1, 1, a) : Qt.rgba(0, 0, 0, a);
  }

  // véu sobre o wallpaper: o oposto
  function veil(a) {
    return themeDark ? Qt.rgba(0, 0, 0, a) : Qt.rgba(1, 1, 1, a);
  }

  readonly property color txt: themeDark ? "#e8edf2" : "#1b2733"

  readonly property color txtMuted: themeDark ? "#8aa0b4" : "#566b7f"

  readonly property color pink: themeDark ? "#e8a0a8" : "#c0455f"

  readonly property color ring: themeDark ? "#e8736b" : "#c93f35"

  readonly property color noteBg: "#d9608f"

  // fundo da tela
  readonly property color cBg1: themeDark ? "#27384a" : "#f1f5f9"

  readonly property color cBg2: themeDark ? "#1a2736" : "#e4ebf2"

  readonly property color cBg3: themeDark ? "#0f1824" : "#d6e0ea"

  // superfícies
  readonly property color cSel: themeDark ? "#34506b" : "#c3d6ea"       // item selecionado

  readonly property color cPop: themeDark ? "#0f1722" : "#f8fafc"       // popups, código

  readonly property color cPopHi: themeDark ? "#1d2b3b" : "#e1e9f1"

  readonly property color cCard: themeDark ? "#1a2a3b" : "#e9eff5"

  readonly property color cCard2: themeDark ? "#1a2736" : "#e9eff5"

  readonly property color cCardHi: themeDark ? "#2a3b4d" : "#cfdbe7"

  readonly property color cLine: themeDark ? "#2c3d50" : "#bccbd9"

  readonly property color cFoco1: themeDark ? "#1f3044" : "#dbe5ef"

  readonly property color cFoco2: themeDark ? "#33475d" : "#b9c9d9"

  readonly property color cTile: themeDark ? "#3a4d62" : "#b8c8d8"

  readonly property color cWarn: themeDark ? "#2a1519" : "#fbe4e1"

  // ícones, textos de apoio e indicadores
  readonly property color cIcon: themeDark ? "#9db2c6" : "#5d7690"

  readonly property color cIconDim: themeDark ? "#4a6078" : "#9fb3c6"

  readonly property color cCode: themeDark ? "#cfd8e0" : "#27384a"

  readonly property color cStatus: themeDark ? "#dfe6ec" : "#243445"

  readonly property color cDim: themeDark ? "#3f5163" : "#b3c2d1"

  readonly property color cBatt: themeDark ? "#cfe8c0" : "#4f9b5b"

  readonly property color cDot: themeDark ? "#6b7d8f" : "#a3b3c3"

  readonly property color cDotOn: themeDark ? "white" : "#243445"

  readonly property color cOk: themeDark ? "#7fd1b0" : "#2e8a68"

  readonly property color cNum: themeDark ? "#e8c25a" : "#9a7300"

  readonly property color hair: root.ov(0.14)

  property alias keyCatcher: keyCatcherItem

  // ================================================================
  // CAPTURA DE TECLADO
  // ================================================================

  Item {
    id: keyCatcherItem

    anchors.fill: parent
    focus: true

    Keys.onPressed: function (e) {
      root.controls.handleKey(e);
    }
  }

  // ================================================================
  // MÓDULOS DE LÓGICA (logic/*.qml) — acesso: root.<instância>.<membro>
  // ================================================================

  // Grade de apps (drun), busca, paginação, apps escondidos, popup de opções
  readonly property AppMenu menu: AppMenu { phone: root }

  // Teclado global, softkeys, D-pad, botões de metal e do teclado numérico
  readonly property KeyControls controls: KeyControls { phone: root }

  // Galeria de wallpapers (waypaper)
  readonly property Wallpapers walls: Wallpapers { phone: root }

  // Compartilhar tela: unir/espelhar monitor externo (hyprctl eval)
  readonly property ScreenShare share: ScreenShare { phone: root }

  // Modo foco (pomodoro)
  readonly property FocusTimer foco: FocusTimer { phone: root }

  // Meus arquivos + troca da foto de perfil
  readonly property FileBrowser files: FileBrowser { phone: root }

  // Info do sistema (fastfetch-like)
  readonly property SystemInfo info: SystemInfo { phone: root }

  // Player MPRIS e relógio
  readonly property MusicPlayer music: MusicPlayer { phone: root }

  // Bateria, Wi-Fi, Bluetooth da barra de status
  readonly property SystemStatus sys: SystemStatus { phone: root }

  // SSH: túnel, pastas, mini terminal, scp, senha no celular
  readonly property SshSession ssh: SshSession { phone: root }

  // Chat com modelos do Ollama
  readonly property AiChat ai: AiChat { phone: root }

  // Configurações (Wi-Fi, Bluetooth, bateria, temas, telas, local, teclado)
  readonly property PhoneSettings config: PhoneSettings { phone: root }

  // Calculadora
  readonly property Calculator calc: Calculator { phone: root }

  // Terminal local (bash persistente)
  readonly property Terminal term: Terminal { phone: root }

  // Agendador de comandos (at)
  readonly property CommandScheduler sched: CommandScheduler { phone: root }

  // Baixador (yt-dlp)
  readonly property Downloader dl: Downloader { phone: root }

  // Notícias RSS
  readonly property NewsReader news: NewsReader { phone: root }

  // Histórico da área de transferência (cliphist)
  readonly property ClipboardHistory clip: ClipboardHistory { phone: root }

  // Jogo da cobrinha
  readonly property Snake snake: Snake { phone: root }

  // ================================================================
  // PALCO (tudo que desliza)
  // ================================================================

  Item {
    id: stage

    width: root.width
    height: root.height

    y: (1 - root.shown) * (root.height + 12)

    // ------------------------------------------------------------
    // CORPO (PNG do Figma)
    // ------------------------------------------------------------

    Image {
      id: bodyImg

      x: fx(0)
      y: fy(0)
      width: s(424)
      height: s(904)

      source: root.bodySource
      smooth: true
      mipmap: true
      asynchronous: true

      // diagnóstico (aparece no terminal onde o qs roda)
      onStatusChanged: {
        const names = ["null", "ready", "loading", "ERROR"];

        console.log(
          "[phone] corpo:", names[status],
          "|", source,
          "| real:", implicitWidth + "x" + implicitHeight
        );
      }
    }

    // aviso visível se o PNG não carregar
    Text {
      visible: bodyImg.status === Image.Error
      anchors.centerIn: parent
      width: parent.width - 40
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap

      text: "phone.png não carregou\n" + root.bodySource
      color: "#ff8a80"
      font.pixelSize: 13
    }

    // ------------------------------------------------------------
    // TELA
    // ------------------------------------------------------------

    Item {
      id: lcd

      x: fx(root.lcdX)
      y: fy(root.lcdY)
      width: s(root.lcdW)
      height: s(root.lcdH)

      // fundo azul-escuro
      Rectangle {
        anchors.fill: parent
        radius: s(6)

        gradient: Gradient {
          GradientStop { position: 0.0; color: root.cBg1 }
          GradientStop { position: 0.55; color: root.cBg2 }
          GradientStop { position: 1.0; color: root.cBg3 }
        }
      }

      // ---------------- wallpaper do celular ----------------
      //   (de baixo pra cima) fundo azul -> wallpaper -> véu preto
      //   translúcido -> ícones/textos

      Item {
        id: wallLayer

        anchors.fill: parent

        visible:
          wallImg.status === Image.Ready
          && (!root.wallOnlyMenu || root.view === "menu")

        layer.enabled: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: wallMask
        }

        Image {
          id: wallImg

          anchors.fill: parent

          source: root.walls.fileUrl(root.celularBg)
          fillMode: Image.PreserveAspectCrop
          sourceSize.height: Math.round(lcd.height * 2)
          asynchronous: true
          smooth: true
        }

        // véu preto translúcido (um pouco mais escuro embaixo, nas softkeys)
        Rectangle {
          anchors.fill: parent

          gradient: Gradient {
            GradientStop {
              position: 0.0
              color: root.veil(Math.max(0, root.wallDim - 0.08))
            }

            GradientStop {
              position: 1.0
              color: root.veil(Math.min(1, root.wallDim + 0.14))
            }
          }
        }
      }

      // máscara com o mesmo canto arredondado da tela
      Rectangle {
        id: wallMask

        anchors.fill: parent
        radius: s(6)
        visible: false
        layer.enabled: true
      }


      StatusBar { phone: root }

      MenuView { phone: root }
      MusicView { phone: root }
      ShareView { phone: root }
      FocoView { phone: root }
      FilesView { phone: root }
      WallView { phone: root }
      InfoView { phone: root }
      SshView { phone: root }
      AiView { phone: root }
      SettingsView { phone: root }
      CalcView { phone: root }
      TermView { phone: root }
      ScheduleView { phone: root }
      DownloadView { phone: root }
      NewsView { phone: root }
      ClipboardView { phone: root }
      SnakeView { phone: root }
      SoftkeyBar { phone: root }
      OptionPopups { phone: root }
    }

    BodyButtons { phone: root }
  }
}
