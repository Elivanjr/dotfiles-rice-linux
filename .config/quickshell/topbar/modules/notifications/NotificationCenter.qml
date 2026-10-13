// NotificationCenter.qml — central de notificações (estilo caderno / dossiê)
//
// Layout 1:1 com a imagem de referência (1686x933).
// Todas as medidas são "pixels da imagem" * sc.
// Pra deixar a central maior/menor, mexe só em `cardWidth`.
//
// Cores: tudo vem de Colors.md3 (matugen).
// Fontes: Caveat (manuscrito), JetBrains Mono (dados), Cormorant Garamond
// (títulos decorativos).
// Ícones: desenhados em Canvas (não dependem de fonte de ícone).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../theme"

PanelWindow {
  id: notifCenter

  required property var screenRef
  screen: screenRef

  property bool panelOpen: false

  visible: panelOpen

  color: "transparent"
  focusable: true

  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  signal closeRequested()
  signal settingsRequested()

  // ================================================================
  // CONFIGURAÇÃO
  // ================================================================

  // largura do card; a altura segue a proporção da imagem
  readonly property int cardWidth: 960
  readonly property real sc: cardWidth / 1686
  readonly property int cardHeight: Math.round(933 * sc)

  // textos da ficha
  property string userName:
    Quickshell.env("USER") || "biscoito"
  property string systemName: "CachyOS (Linux)"
  property string wmName:
    Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland"
  property string weaknessText: "Tsunderes"
  property string focusText: "Coding"
  property string quoteText: "I'm on it"

  // foto de perfil (AccountsService)
  property string photoSource:
    "file:///var/lib/AccountsService/icons/" + userName

  // true = usa o ícone real do app dentro do quadradinho colorido
  property bool useAppIcons: false

  // fontes
  readonly property string fontHand: "Caveat"
  readonly property string fontMono: "JetBrains Mono"
  readonly property string fontSerif: "Cormorant Garamond"
  readonly property string fontIcon: "Font Awesome 6 Free"

  // ================================================================
  // CORES (Colors.md3)
  // ================================================================

  readonly property color colPaper: Colors.md3.surface
  readonly property color colPanel: Colors.md3.surface_container
  readonly property color colInk: Colors.md3.on_surface
  readonly property color colInkSoft: Colors.md3.outline
  readonly property color colAccent: Colors.md3.primary
  readonly property color colOnAccent: Colors.md3.on_primary
  readonly property color colError: Colors.md3.error
  readonly property color colEdge: Colors.md3.outline_variant

  readonly property color colHair:
    Qt.rgba(colInk.r, colInk.g, colInk.b, 0.16)
  readonly property color colRule:
    Qt.rgba(colInk.r, colInk.g, colInk.b, 0.07)

  // ================================================================
  // ESTADO
  // ================================================================

  property var now: new Date()
  property string uptimeText: "--h --m"

  readonly property int notifCount:
    NotificationService.notifHistory
      ? NotificationService.notifHistory.length
      : 0

  readonly property var monthShort: [
    "Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
    "Jul", "Ago", "Set", "Out", "Nov", "Dez"
  ]

  function pad2(n) {
    return (n < 10 ? "0" : "") + n;
  }

  function clockText() {
    return pad2(now.getHours()) + ":" + pad2(now.getMinutes());
  }

  function dateText() {
    return now.getDate() + " "
      + monthShort[now.getMonth()]
      + " · " + clockText();
  }

  Timer {
    interval: 15000
    running: notifCenter.panelOpen
    repeat: true
    triggeredOnStart: true

    onTriggered: {
      notifCenter.now = new Date();
      uptimeProc.running = true;
    }
  }

  Process {
    id: uptimeProc

    command: ["cat", "/proc/uptime"]
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        const secs = parseFloat(text.split(" ")[0]);

        if (isNaN(secs))
          return;

        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);

        notifCenter.uptimeText =
          notifCenter.pad2(h) + "h " + notifCenter.pad2(m) + "m";
      }
    }
  }

  // ================================================================
  // ÍCONES DESENHADOS (Canvas, grade 24x24)
  // ================================================================

  component Glyph: Canvas {
    property string kind: ""
    property color stroke: "white"
    property real lw: 1.9

    implicitWidth: 24
    implicitHeight: 24

    onKindChanged: requestPaint()
    onStrokeChanged: requestPaint()
    onLwChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      const ctx = getContext("2d");
      ctx.clearRect(0, 0, width, height);
      ctx.save();
      ctx.scale(width / 24, height / 24);

      ctx.strokeStyle = stroke;
      ctx.fillStyle = stroke;
      ctx.lineWidth = lw;
      ctx.lineCap = "round";
      ctx.lineJoin = "round";

      const TAU = Math.PI * 2;

      const rr = function (x, y, w, h, r) {
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + w - r, y);
        ctx.arcTo(x + w, y, x + w, y + r, r);
        ctx.lineTo(x + w, y + h - r);
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
        ctx.lineTo(x + r, y + h);
        ctx.arcTo(x, y + h, x, y + h - r, r);
        ctx.lineTo(x, y + r);
        ctx.arcTo(x, y, x + r, y, r);
        ctx.closePath();
      };

      const dot = function (x, y, r) {
        ctx.beginPath();
        ctx.arc(x, y, r, 0, TAU);
        ctx.fill();
      };

      const line = function (x1, y1, x2, y2) {
        ctx.beginPath();
        ctx.moveTo(x1, y1);
        ctx.lineTo(x2, y2);
        ctx.stroke();
      };

      switch (kind) {
      case "bell":
        ctx.beginPath();
        ctx.arc(12, 8, 6, Math.PI, 0, false);
        ctx.bezierCurveTo(18, 15, 21, 17, 21, 17);
        ctx.lineTo(3, 17);
        ctx.bezierCurveTo(3, 17, 6, 15, 6, 8);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(12, 20, 2, 0, Math.PI, false);
        ctx.stroke();
        break;

      case "trash":
        line(4, 6, 20, 6);
        ctx.beginPath();
        ctx.moveTo(9, 6);
        ctx.lineTo(9, 3.8);
        ctx.lineTo(15, 3.8);
        ctx.lineTo(15, 6);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(6, 6);
        ctx.lineTo(7, 20.5);
        ctx.lineTo(17, 20.5);
        ctx.lineTo(18, 6);
        ctx.stroke();
        line(10, 10, 10, 16.5);
        line(14, 10, 14, 16.5);
        break;

      case "gear":
        ctx.beginPath();
        for (let i = 0; i < 8; i++) {
          const a = i * Math.PI / 4;
          const pts = [
            [a - 0.30, 7.6],
            [a - 0.18, 9.8],
            [a + 0.18, 9.8],
            [a + 0.30, 7.6]
          ];

          for (let j = 0; j < 4; j++) {
            const px = 12 + pts[j][1] * Math.cos(pts[j][0]);
            const py = 12 + pts[j][1] * Math.sin(pts[j][0]);

            if (i === 0 && j === 0)
              ctx.moveTo(px, py);
            else
              ctx.lineTo(px, py);
          }
        }
        ctx.closePath();
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(12, 12, 3.2, 0, TAU);
        ctx.stroke();
        break;

      case "clock":
        ctx.beginPath();
        ctx.arc(12, 12, 9, 0, TAU);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(12, 6.5);
        ctx.lineTo(12, 12);
        ctx.lineTo(15.8, 14.2);
        ctx.stroke();
        break;

      case "mail":
        rr(3, 5, 18, 14, 2);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(3.5, 6.5);
        ctx.lineTo(12, 13.5);
        ctx.lineTo(20.5, 6.5);
        ctx.stroke();
        break;

      case "target":
        ctx.beginPath();
        ctx.arc(12, 12, 6.5, 0, TAU);
        ctx.stroke();
        dot(12, 12, 2);
        line(12, 2, 12, 5.5);
        line(12, 18.5, 12, 22);
        line(2, 12, 5.5, 12);
        line(18.5, 12, 22, 12);
        break;

      case "chat":
        rr(3, 4, 18, 13, 3);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(8, 17);
        ctx.lineTo(8, 21);
        ctx.lineTo(12.5, 17);
        ctx.stroke();
        dot(8, 10.5, 1.2);
        dot(12, 10.5, 1.2);
        dot(16, 10.5, 1.2);
        break;

      case "download":
        ctx.beginPath();
        ctx.moveTo(4, 15);
        ctx.lineTo(4, 19.5);
        ctx.lineTo(20, 19.5);
        ctx.lineTo(20, 15);
        ctx.stroke();
        line(12, 4, 12, 15);
        ctx.beginPath();
        ctx.moveTo(7, 10.5);
        ctx.lineTo(12, 15.5);
        ctx.lineTo(17, 10.5);
        ctx.stroke();
        break;

      case "refresh":
        ctx.beginPath();
        ctx.arc(12, 12, 7.5, 3.4, 6.0, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(20, 4.5);
        ctx.lineTo(20, 10.5);
        ctx.lineTo(14.5, 10.5);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(12, 12, 7.5, 0.25, 2.85, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(4, 19.5);
        ctx.lineTo(4, 13.5);
        ctx.lineTo(9.5, 13.5);
        ctx.stroke();
        break;

      case "info":
        ctx.beginPath();
        ctx.arc(12, 12, 9.5, 0, TAU);
        ctx.stroke();
        line(12, 11, 12, 17);
        dot(12, 7.6, 1.2);
        break;

      case "calendar":
        rr(3, 5, 18, 16, 2.5);
        ctx.stroke();
        line(3, 10, 21, 10);
        line(8, 3, 8, 7);
        line(16, 3, 16, 7);
        ctx.fillRect(7, 12.8, 1.7, 1.7);
        ctx.fillRect(11.2, 12.8, 1.7, 1.7);
        ctx.fillRect(15.4, 12.8, 1.7, 1.7);
        ctx.fillRect(7, 16.6, 1.7, 1.7);
        ctx.fillRect(11.2, 16.6, 1.7, 1.7);
        ctx.fillRect(15.4, 16.6, 1.7, 1.7);
        break;

      case "shield":
        ctx.beginPath();
        ctx.moveTo(12, 3);
        ctx.lineTo(19.5, 6);
        ctx.lineTo(19.5, 12);
        ctx.bezierCurveTo(19.5, 17, 16, 20, 12, 21.5);
        ctx.bezierCurveTo(8, 20, 4.5, 17, 4.5, 12);
        ctx.lineTo(4.5, 6);
        ctx.closePath();
        ctx.stroke();
        break;
      }

      ctx.restore();
    }
  }

  component IconButton: Item {
    id: btn

    property string kind: ""
    property color stroke: "white"
    property real iconSize: 24

    signal clicked()

    width: iconSize + 14
    height: iconSize + 14

    Glyph {
      anchors.centerIn: parent
      width: btn.iconSize
      height: btn.iconSize
      kind: btn.kind
      stroke: btn.stroke
      opacity: ma.containsMouse ? 1.0 : 0.75
    }

    MouseArea {
      id: ma

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      onClicked: btn.clicked()
    }
  }

  // ================================================================
  // ESTILO DOS QUADRADINHOS DAS NOTIFICAÇÕES
  // ================================================================

  function resolveIcon(icon) {
    if (!icon || icon === "")
      return "";

    if (
      icon.startsWith("file://") ||
      icon.startsWith("http://") ||
      icon.startsWith("https://") ||
      icon.startsWith("image://")
    ) {
      return icon;
    }

    if (icon.startsWith("/"))
      return "file://" + icon;

    return Quickshell.iconPath(icon, "");
  }

  function styleFor(n) {
    const t = (
      (n.appName || "") + " " + (n.summary || "")
    ).toLowerCase();

    const m = Colors.md3;

    if (/download|baixad/.test(t))
      return { glyph: "download", bg: m.source_color, fg: m.surface };

    if (/atualiza|update|upgrade|pacman|paru|yay/.test(t))
      return { glyph: "refresh", bg: m.error, fg: m.surface };

    if (/calend|agenda|evento|aula/.test(t))
      return {
        glyph: "calendar",
        bg: Qt.darker(m.primary, 1.35),
        fg: m.surface
      };

    if (/brave|chrome|firefox|navegador|browser/.test(t))
      return {
        glyph: "shield",
        bg: Qt.darker(m.source_color, 1.35),
        fg: m.surface
      };

    if (/ollama|info/.test(t))
      return { glyph: "info", bg: m.outline, fg: m.surface };

    if (/mensag|message|discord|telegram|whatsapp|signal|chat/.test(t))
      return { glyph: "chat", bg: m.primary, fg: m.on_primary };

    return {
      glyph: "gear",
      bg: m.surface_container_highest,
      fg: m.on_surface
    };
  }

  // ================================================================
  // JANELA
  // ================================================================

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  exclusiveZone: 0

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "quickshell:notifcenter"

  onPanelOpenChanged: {
    if (!panelOpen)
      return;

    card.forceActiveFocus();
  }

  // clique fora do card fecha
  MouseArea {
    anchors.fill: parent
    onClicked: notifCenter.closeRequested()
  }

  // ================================================================
  // CARD
  // ================================================================

  Rectangle {
    id: card

    x: Math.round((parent.width - width) / 2)
    y: 6
    width: notifCenter.cardWidth
    height: notifCenter.cardHeight

    radius: 6
    clip: true

    color: notifCenter.colPaper

    border.color: notifCenter.colEdge
    border.width: 1

    focus: true

    Keys.onEscapePressed:
      notifCenter.closeRequested()

    // engole cliques em áreas vazias do card
    MouseArea {
      anchors.fill: parent
    }

    // ------------------------------------------------------------
    // PAUTA
    // ------------------------------------------------------------

    Canvas {
      id: rules

      anchors.fill: parent

      property color lineColor: notifCenter.colRule

      onLineColorChanged: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()

      onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.strokeStyle = lineColor;
        ctx.lineWidth = 1;

        const step = 26 * notifCenter.sc;

        for (let y = step; y < height; y += step) {
          ctx.beginPath();
          ctx.moveTo(0, Math.round(y) + 0.5);
          ctx.lineTo(width, Math.round(y) + 0.5);
          ctx.stroke();
        }
      }
    }

    // separador vertical ficha | notificações
    Rectangle {
      x: 537 * sc
      width: 1
      height: parent.height
      color: notifCenter.colEdge
    }

    // ============================================================
    // ESQUERDA — FICHA
    // ============================================================

    // moldura da polaroid
    Rectangle {
      x: 40 * sc
      y: 30 * sc
      width: 420 * sc
      height: 420 * sc

      color: notifCenter.colPanel
      border.color: notifCenter.colEdge
      border.width: 1
    }

    // foto
    Rectangle {
      x: 50 * sc
      y: 40 * sc
      width: 400 * sc
      height: 400 * sc

      color: notifCenter.colPanel
      clip: true

      Image {
        anchors.fill: parent
        source: notifCenter.photoSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
      }
    }

    // clipe de papel
    Text {
      x: 26 * sc
      y: 8 * sc

      text: "\u{F0C6}"
      rotation: -30

      color: notifCenter.colInkSoft
      font.family: notifCenter.fontIcon
      font.pixelSize: 58 * sc
    }

    // "試験対象" vertical
    Repeater {
      model: ["試", "験", "対", "象"]

      Text {
        required property string modelData
        required property int index

        x: 479 * sc - width / 2
        y: (78 + index * 39.3) * sc - height / 2

        text: modelData
        color: notifCenter.colInkSoft
        font.pixelSize: 34 * sc
      }
    }

    Rectangle {
      x: 478 * sc
      y: 226 * sc
      width: Math.max(1, 2 * sc)
      height: 14 * sc
      color: notifCenter.colInkSoft
    }

    Rectangle {
      x: 478 * sc
      y: 254 * sc
      width: Math.max(1, 2 * sc)
      height: 14 * sc
      color: notifCenter.colInkSoft
    }

    Text {
      x: 481 * sc - width / 2
      y: 304 * sc - height / 2

      text: "001"
      rotation: 90

      color: notifCenter.colInkSoft
      font.family: notifCenter.fontMono
      font.pixelSize: 21 * sc
    }

    // moldura IDENTIFICATION
    Rectangle {
      x: 28 * sc
      y: 460 * sc
      width: 483 * sc
      height: 433 * sc

      color: Qt.rgba(
        notifCenter.colPanel.r,
        notifCenter.colPanel.g,
        notifCenter.colPanel.b,
        0.55
      )
      border.color: notifCenter.colInkSoft
      border.width: Math.max(1, 1.5 * sc)
    }

    Rectangle {
      x: 38 * sc
      y: 461 * sc
      width: 146 * sc
      height: 21 * sc

      color: notifCenter.colPaper
      border.color: notifCenter.colInkSoft
      border.width: 1

      Text {
        anchors.centerIn: parent

        text: "IDENTIFICATION"
        font.italic: true
        font.weight: Font.DemiBold
        color: notifCenter.colInkSoft
        font.family: notifCenter.fontSerif
        font.pixelSize: 19 * sc
      }
    }

    // User / System / WM
    Repeater {
      model: [
        { l: "User:",   v: notifCenter.userName,   yy: 509 },
        { l: "System:", v: notifCenter.systemName, yy: 539 },
        { l: "WM:",     v: notifCenter.wmName,     yy: 569 }
      ]

      Item {
        required property var modelData

        Text {
          x: 47 * sc
          y: modelData.yy * sc - height / 2

          text: modelData.l
          font.italic: true
          color: notifCenter.colInkSoft
          font.family: notifCenter.fontMono
          font.pixelSize: 18 * sc
        }

        Text {
          x: 183 * sc
          y: modelData.yy * sc - height / 2

          text: modelData.v
          color: notifCenter.colInk
          font.family: notifCenter.fontMono
          font.pixelSize: 18 * sc
        }
      }
    }

    // divisórias da ficha
    Repeater {
      model: [592, 655, 738, 780, 822]

      Rectangle {
        required property int modelData

        x: 47 * sc
        y: modelData * sc
        width: 445 * sc
        height: 1
        color: notifCenter.colHair
      }
    }

    // WEAKNESS
    Text {
      x: 47 * sc
      y: 614 * sc - height / 2

      text: "WEAKNESS"
      font.italic: true
      color: notifCenter.colInkSoft
      font.family: notifCenter.fontMono
      font.pixelSize: 15 * sc
    }

    Text {
      x: 75 * sc
      y: 638 * sc - height / 2

      text: notifCenter.weaknessText
      color: notifCenter.colError
      font.family: notifCenter.fontMono
      font.pixelSize: 16 * sc
    }

    // SESSION STATUS
    Text {
      x: 47 * sc
      y: 678 * sc - height / 2

      text: "SESSION STATUS"
      font.italic: true
      font.weight: Font.DemiBold
      color: notifCenter.colInkSoft
      font.family: notifCenter.fontSerif
      font.pixelSize: 21 * sc
    }

    Rectangle {
      x: 47 * sc
      y: 701 * sc
      width: 14 * sc
      height: 14 * sc
      radius: width / 2
      color: notifCenter.colAccent
    }

    Text {
      x: 73 * sc
      y: 708 * sc - height / 2

      text: "Online"
      font.italic: true
      color: notifCenter.colInkSoft
      font.family: notifCenter.fontMono
      font.pixelSize: 18 * sc
    }

    Glyph {
      x: 183 * sc
      y: 708 * sc - height / 2
      width: 21 * sc
      height: 21 * sc
      kind: "clock"
      stroke: notifCenter.colInkSoft
    }

    Text {
      x: 214 * sc
      y: 708 * sc - height / 2

      text: notifCenter.clockText()
      color: notifCenter.colInk
      font.family: notifCenter.fontMono
      font.pixelSize: 17 * sc
    }

    Glyph {
      x: 305 * sc
      y: 708 * sc - height / 2
      width: 21 * sc
      height: 21 * sc
      kind: "mail"
      stroke: notifCenter.colInkSoft
    }

    Text {
      x: 336 * sc
      y: 708 * sc - height / 2

      text: notifCenter.pad2(notifCenter.notifCount) + " unread"
      font.italic: true
      color: notifCenter.colInkSoft
      font.family: notifCenter.fontMono
      font.pixelSize: 17 * sc
    }

    // UPTIME
    Text {
      x: 47 * sc
      y: 762 * sc - height / 2

      text: "UPTIME"
      font.italic: true
      color: notifCenter.colInkSoft
      font.family: notifCenter.fontMono
      font.pixelSize: 15 * sc
    }

    Glyph {
      x: 189 * sc
      y: 762 * sc - height / 2
      width: 21 * sc
      height: 21 * sc
      kind: "clock"
      stroke: notifCenter.colInkSoft
    }

    Text {
      x: 223 * sc
      y: 762 * sc - height / 2

      text: notifCenter.uptimeText
      color: notifCenter.colInk
      font.family: notifCenter.fontMono
      font.pixelSize: 16 * sc
    }

    // CURRENT FOCUS
    Text {
      x: 47 * sc
      y: 801 * sc - height / 2

      text: "CURRENT FOCUS"
      font.italic: true
      color: notifCenter.colInkSoft
      font.family: notifCenter.fontMono
      font.pixelSize: 15 * sc
    }

    Glyph {
      x: 191 * sc
      y: 801 * sc - height / 2
      width: 23 * sc
      height: 23 * sc
      kind: "target"
      stroke: notifCenter.colInkSoft
    }

    Text {
      x: 225 * sc
      y: 801 * sc - height / 2

      text: notifCenter.focusText
      color: notifCenter.colAccent
      font.family: notifCenter.fontMono
      font.pixelSize: 17 * sc
    }

    // citação manuscrita
    Text {
      x: 47 * sc
      y: 858 * sc - height / 2

      text: "\u201C" + notifCenter.quoteText + "\u201D"
      color: notifCenter.colInkSoft
      font.family: notifCenter.fontHand
      font.pixelSize: 30 * sc
    }

    // carimbo TOP SECRET
    Item {
      width: 262 * sc
      height: 76 * sc

      x: 376 * sc - width / 2
      y: 842 * sc - height / 2

      rotation: -15
      opacity: 0.7

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: notifCenter.colError
        border.width: Math.max(1, 3 * sc)
      }

      Rectangle {
        anchors.fill: parent
        anchors.margins: 6 * sc
        color: "transparent"
        border.color: notifCenter.colError
        border.width: Math.max(1, 1.5 * sc)
      }

      Text {
        anchors.centerIn: parent

        text: "TOP SECRET"
        font.bold: true
        color: notifCenter.colError
        font.family: notifCenter.fontSerif
        font.pixelSize: 50 * sc
      }
    }

    // ============================================================
    // DIREITA — CABEÇALHO
    // ============================================================

    Text {
      x: 567 * sc
      y: 38 * sc - height / 2

      text: "Central de Notificações"
      color: notifCenter.colAccent
      font.family: notifCenter.fontHand
      font.weight: Font.DemiBold
      font.pixelSize: 46 * sc
    }

    Glyph {
      x: 1400 * sc - width / 2
      y: 38 * sc - height / 2
      width: 30 * sc
      height: 30 * sc
      kind: "bell"
      stroke: notifCenter.colInk
    }

    Rectangle {
      visible: notifCenter.notifCount > 0

      x: 1414 * sc - width / 2
      y: 25 * sc - height / 2
      width: 24 * sc
      height: 24 * sc
      radius: width / 2

      color: notifCenter.colError

      Text {
        anchors.centerIn: parent

        text: notifCenter.notifCount > 9
          ? "9+"
          : notifCenter.notifCount

        color: notifCenter.colPaper
        font.bold: true
        font.family: notifCenter.fontMono
        font.pixelSize: 14 * sc
      }
    }

    Rectangle {
      x: 1437 * sc
      y: 28 * sc
      width: 1
      height: 28 * sc
      color: notifCenter.colHair
    }

    Text {
      x: 1456 * sc
      y: 42 * sc - height / 2

      text: notifCenter.dateText()
      color: notifCenter.colAccent
      font.family: notifCenter.fontHand
      font.weight: Font.DemiBold
      font.pixelSize: 35 * sc
    }

    // linha sob o cabeçalho
    Rectangle {
      x: 568 * sc
      y: 69 * sc
      width: 1084 * sc
      height: Math.max(1, 2 * sc)
      color: notifCenter.colAccent
    }

    // ============================================================
    // LISTA
    // ============================================================

    ListView {
      id: notificationList

      x: 568 * sc
      y: 76 * sc
      width: 1084 * sc
      height: 762 * sc

      clip: true
      spacing: 0
      boundsBehavior: Flickable.StopAtBounds

      model:
        NotificationService.notifHistory

      delegate: Item {
        id: row

        required property var modelData

        readonly property var st:
          notifCenter.styleFor(modelData)

        readonly property string realIcon:
          notifCenter.resolveIcon(modelData.image)
          || notifCenter.resolveIcon(modelData.appIcon)

        readonly property bool showReal:
          notifCenter.useAppIcons && realIcon !== ""

        width: notificationList.width

        height:
          Math.max(48 * sc, textCol.implicitHeight) + 42 * sc

        // quadradinho do ícone
        Rectangle {
          x: 20 * sc
          y: 21 * sc
          width: 48 * sc
          height: 48 * sc
          radius: 10 * sc

          color: row.st.bg
          clip: true

          Glyph {
            anchors.centerIn: parent
            width: 27 * sc
            height: 27 * sc
            visible: !row.showReal

            kind: row.st.glyph
            stroke: row.st.fg
          }

          Image {
            anchors.fill: parent
            anchors.margins: 6 * sc

            visible: row.showReal

            source: row.realIcon
            fillMode: Image.PreserveAspectFit
            asynchronous: true
          }
        }

        // texto
        Column {
          id: textCol

          x: 104 * sc
          y: 24 * sc
          width: row.width - 104 * sc - 160 * sc

          spacing: 0

          Text {
            width: parent.width

            text: modelData.summary
            elide: Text.ElideRight

            color: notifCenter.colInk
            font.family: notifCenter.fontMono
            font.bold: true
            font.pixelSize: 19 * sc

            lineHeightMode: Text.FixedHeight
            lineHeight: 25 * sc
          }

          Text {
            visible: modelData.body !== ""
            width: parent.width

            text: modelData.body
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight

            color: notifCenter.colInkSoft
            font.family: notifCenter.fontMono
            font.pixelSize: 18 * sc

            lineHeightMode: Text.FixedHeight
            lineHeight: 25 * sc
          }
        }

        // tempo
        Text {
          x: 1059 * sc - width
          y: 54 * sc - height / 2

          text: modelData.time
          color: notifCenter.colInkSoft
          font.family: notifCenter.fontMono
          font.pixelSize: 16 * sc
        }

        // bolinha
        Rectangle {
          x: 1074 * sc - width / 2
          y: 48 * sc - height / 2
          width: 10 * sc
          height: 10 * sc
          radius: width / 2

          color: notifCenter.colInkSoft
        }

        // separador
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: 1

          color: notifCenter.colHair
        }
      }

      // estado vazio
      Text {
        anchors.centerIn: parent
        visible: notifCenter.notifCount === 0

        text: "Nenhuma notificação"
        color: notifCenter.colInkSoft
        font.family: notifCenter.fontHand
        font.pixelSize: 36 * sc
      }
    }

    // ============================================================
    // BARRA INFERIOR
    // ============================================================

    // "Não perturbe" + toggle (um do lado do outro, sem sobrepor)
    Row {
      x: 588 * sc
      y: 875 * sc - height / 2

      spacing: 16 * sc

      Text {
        anchors.verticalCenter: parent.verticalCenter

        text: "Não perturbe"
        color: notifCenter.colInkSoft
        font.family: notifCenter.fontHand
        font.pixelSize: 33 * sc
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter

        width: 50 * sc
        height: 28 * sc
        radius: height / 2

        color:
          NotificationService.dndEnabled
            ? notifCenter.colAccent
            : notifCenter.colEdge

        Rectangle {
          width: 22 * sc
          height: 22 * sc
          radius: width / 2

          anchors.verticalCenter: parent.verticalCenter

          x:
            NotificationService.dndEnabled
              ? parent.width - width - 3 * sc
              : 3 * sc

          color:
            NotificationService.dndEnabled
              ? notifCenter.colOnAccent
              : notifCenter.colInk

          Behavior on x {
            NumberAnimation {
              duration: 140
            }
          }
        }

        MouseArea {
          anchors.fill: parent

          cursorShape: Qt.PointingHandCursor

          onClicked:
            NotificationService.dndEnabled =
              !NotificationService.dndEnabled
        }
      }
    }

    // apagar todas
    IconButton {
      x: 1351 * sc - width / 2
      y: 877 * sc - height / 2

      kind: "trash"
      iconSize: 28 * sc
      stroke: notifCenter.colInk

      onClicked:
        NotificationService.clearNotifHistory()
    }

    Rectangle {
      x: 1400 * sc
      y: 860 * sc
      width: 1
      height: 34 * sc
      color: notifCenter.colHair
    }

    // sino -> alterna "Não perturbe"
    IconButton {
      x: 1449 * sc - width / 2
      y: 877 * sc - height / 2

      kind: "bell"
      iconSize: 28 * sc
      stroke:
        NotificationService.dndEnabled
          ? notifCenter.colAccent
          : notifCenter.colInk

      onClicked:
        NotificationService.dndEnabled =
          !NotificationService.dndEnabled
    }

    Rectangle {
      x: 1498 * sc
      y: 860 * sc
      width: 1
      height: 34 * sc
      color: notifCenter.colHair
    }

    // engrenagem
    IconButton {
      x: 1547 * sc - width / 2
      y: 877 * sc - height / 2

      kind: "gear"
      iconSize: 28 * sc
      stroke: notifCenter.colInk

      onClicked:
        notifCenter.settingsRequested()
    }

    Rectangle {
      x: 1597 * sc
      y: 860 * sc
      width: 1
      height: 34 * sc
      color: notifCenter.colHair
    }

    // X (fechar)
    Item {
      x: 1643 * sc - width / 2
      y: 880 * sc - height / 2
      width: 38 * sc
      height: 38 * sc

      Rectangle {
        anchors.centerIn: parent
        width: 38 * sc
        height: Math.max(1.5, 2 * sc)
        rotation: 45
        color: notifCenter.colInk
      }

      Rectangle {
        anchors.centerIn: parent
        width: 38 * sc
        height: Math.max(1.5, 2 * sc)
        rotation: -45
        color: notifCenter.colInk
      }

      MouseArea {
        anchors.fill: parent

        cursorShape: Qt.PointingHandCursor

        onClicked:
          notifCenter.closeRequested()
      }
    }
  }
}
