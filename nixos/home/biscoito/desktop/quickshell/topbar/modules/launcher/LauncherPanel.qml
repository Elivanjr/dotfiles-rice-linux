// LauncherPanel.qml — launcher nativo do Quickshell, estilo gaveta de apps
// do One UI (Samsung) em modo paisagem.
//
// Visual: tela cheia em cima de tudo (layer Overlay) EXCETO a topbar, que
// continua visível e clicável. O fundo é um véu translúcido; o desfoque de
// verdade (wallpaper/janelas atrás) vem do compositor via layer_rule do
// Hyprland (veja o bloco no fim deste comentário).
//
// Modos (mesmos de antes, trocam por Tab / Ctrl+1..3 / clique nos ícones):
//   DRUN   -> aplicativos (DesktopEntries). Ordenação: A–Z ou Mais usados.
//             O contador de uso e a ordenação escolhida ficam salvos em
//             ~/.local/state/quickshell-launcher/usage.json
//   Files  -> navegador de pastas (xdg-open nos arquivos)
//   Window -> janelas abertas no Hyprland
//
// Atalhos: digite pra filtrar · setas navegam na grade · Enter ativa ·
// Backspace com busca vazia sobe uma pasta (Files) · Tab troca de modo ·
// Ctrl+1/2/3 vai direto pro modo · Esc ou clique fora fecha.
//
// Blur no hyprland.lua (precisa de decoration.blur.enabled = true):
//   hl.layer_rule({
//     name = "quickshell-launcher-blur",
//     match = { namespace = "quickshell:launcher" },
//     blur = true,
//     ignore_alpha = 0,
//   })

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../theme"

PanelWindow {
  id: launcher

  required property var screenRef
  property bool panelOpen: false
  signal closeRequested()

  // repassados pelo shell.qml pra combinar com o resto da topbar
  property string nerdFont: "JetBrainsMono NF"
  property int barHeight: 39
  property int barMargin: 6

  // espaço reservado no topo pra topbar continuar visível (barra + margem
  // de cima + um respiro). Ajuste se a sua topbar ocupar outra altura.
  property int topInset: barHeight + barMargin * 2

  screen: screenRef
  visible: panelOpen
  color: "transparent"

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.namespace: "quickshell:launcher"

  // ignora a exclusive zone da topbar e usa a margem manual abaixo,
  // assim o painel não depende de como a topbar reserva espaço
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  margins {
    top: launcher.topInset
  }

  // ---------- paleta ----------
  readonly property color colScrim: Qt.alpha(Colors.md3.surface, 0.52)
  readonly property color colPill: Qt.alpha(Colors.md3.surface_container, 0.78)
  readonly property color colText: Colors.md3.source_color
  readonly property color colMuted: Qt.alpha(Colors.md3.source_color, 0.72)
  readonly property color colAccent: Colors.md3.primary

  // ---------- ícones sem quadrado roxo/preto quebrado ----------
  function resolveIcon(name) {
    if (!name)
      return "";
    return Quickshell.iconPath(name, true);
  }

  // ---------- estado ----------
  property string mode: "drun" // drun | files | window
  property string query: ""
  property var results: []
  property real reveal: 0 // 0 -> 1 na animação de abertura

  readonly property var modes: [
    { id: "drun", label: "Apps", icon: "\uf00a" },
    { id: "files", label: "Arquivos", icon: "\uf07c" },
    { id: "window", label: "Janelas", icon: "\uf108" }
  ]

  readonly property var sortOptions: [
    { id: "alpha", label: "A–Z" },
    { id: "usage", label: "Mais usados" }
  ]

  readonly property var placeholders: ({
    drun: "Pesquisar aplicativos...",
    files: "Filtrar nesta pasta...",
    window: "Pesquisar janelas abertas..."
  })

  function closeLauncher() {
    launcher.closeRequested();
  }

  function resetState() {
    query = "";
    searchInput.text = "";
    resultsGrid.currentIndex = 0;
  }

  NumberAnimation {
    id: revealAnim
    target: launcher
    property: "reveal"
    from: 0
    to: 1
    duration: 170
    easing.type: Easing.OutCubic
  }

  onPanelOpenChanged: {
    if (panelOpen) {
      resetState();
      if (mode === "files" && dirEntries.length === 0)
        loadDirectory(currentDir);
      recomputeResults();
      searchInput.forceActiveFocus();
      revealAnim.restart();
    }
  }

  function switchMode(newMode) {
    mode = newMode;
    resultsGrid.currentIndex = 0;
    if (mode === "files" && dirEntries.length === 0)
      loadDirectory(currentDir);
    recomputeResults();
  }

  // =====================================================================
  // USO / ORDENAÇÃO — contador por app, salvo em JSON
  // =====================================================================
  property string sortMode: "alpha" // alpha | usage
  property var usage: ({}) // { desktopEntryId: vezesAberto }

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell-launcher"

  Component.onCompleted: {
    Quickshell.execDetached({ command: ["mkdir", "-p", launcher.stateDir] });
  }

  FileView {
    id: usageFile
    path: launcher.stateDir + "/usage.json"
    printErrors: false

    onLoaded: {
      try {
        const data = JSON.parse(usageFile.text());
        launcher.usage = data.counts || {};
        if (data.sort === "alpha" || data.sort === "usage")
          launcher.sortMode = data.sort;
      } catch (e) {
        // arquivo vazio/corrompido: começa do zero
      }
      launcher.recomputeResults();
    }
  }

  function saveState() {
    usageFile.setText(JSON.stringify({ sort: sortMode, counts: usage }));
  }

  function bumpUsage(id) {
    if (!id)
      return;
    const next = Object.assign({}, usage);
    next[id] = (next[id] || 0) + 1;
    usage = next;
    saveState();
  }

  function setSortMode(newSort) {
    if (sortMode === newSort)
      return;
    sortMode = newSort;
    saveState();
    resultsGrid.currentIndex = 0;
    recomputeResults();
  }

  // =====================================================================
  // DRUN — aplicativos
  // =====================================================================
  readonly property string drunFallbackGlyph: "\uf085" // fa-cogs

  function drunResults(q) {
    const needle = q.toLowerCase();
    let list = DesktopEntries.applications.values.filter((e) => {
      if (!needle) return true;
      return (e.name || "").toLowerCase().indexOf(needle) !== -1
        || (e.genericName || "").toLowerCase().indexOf(needle) !== -1
        || (e.comment || "").toLowerCase().indexOf(needle) !== -1;
    });

    list.sort((a, b) => {
      if (launcher.sortMode === "usage") {
        const diff = (launcher.usage[b.id] || 0) - (launcher.usage[a.id] || 0);
        if (diff !== 0)
          return diff;
      }
      return (a.name || "").localeCompare(b.name || "");
    });

    return list.map((e) => ({
      label: e.name || e.id,
      iconSource: resolveIcon(e.icon),
      glyph: drunFallbackGlyph,
      activate: () => {
        launcher.bumpUsage(e.id);
        e.execute();
        closeLauncher();
      }
    }));
  }

  // =====================================================================
  // WINDOW — janelas abertas via Hyprland
  // =====================================================================
  readonly property string windowFallbackGlyph: "\uf2d0" // fa-window-restore

  function iconForAppId(appId) {
    const entry = appId ? DesktopEntries.heuristicLookup(appId) : null;
    const iconName = entry && entry.icon ? entry.icon : appId;
    return resolveIcon(iconName);
  }

  function windowResults(q) {
    const needle = q.toLowerCase();
    let list = Hyprland.toplevels.values.filter((t) => {
      const appId = (t.wayland && t.wayland.appId) || "";
      if (!needle) return true;
      return (t.title || "").toLowerCase().indexOf(needle) !== -1
        || appId.toLowerCase().indexOf(needle) !== -1;
    });

    return list.map((t) => {
      const appId = (t.wayland && t.wayland.appId) || "";
      return {
        label: t.title || appId || "(sem título)",
        iconSource: iconForAppId(appId),
        glyph: windowFallbackGlyph,
        activate: () => {
          // Hyprland em modo Lua: o objeto de workspace sabe ativar o
          // workspace, e o Toplevel Wayland tem activate() pra dar foco.
          const workspace = t.workspace;
          const toplevel = t.wayland;

          closeLauncher();

          Qt.callLater(() => {
            if (workspace)
              workspace.activate();

            Qt.callLater(() => {
              if (toplevel)
                toplevel.activate();
            });
          });
        }
      };
    });
  }

  // =====================================================================
  // FILES — navegador de diretório de verdade (não é busca recursiva)
  // =====================================================================
  readonly property string folderGlyph: "\uf07b" // fa-folder
  readonly property string fileGlyph: "\uf15b" // fa-file
  readonly property string upGlyph: "\uf148" // fa-level-up (a entrada "..")

  property string currentDir: Quickshell.env("HOME")
  property var dirEntries: [] // [{name, isDir}], sem a ".."

  Process {
    id: dirProc
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = this.text.split("\n").filter((l) => l.length > 0);
        let entries = lines.map((line) => {
          const tab = line.indexOf("\t");
          const kind = line.slice(0, tab);
          const name = line.slice(tab + 1);
          return { name: name, isDir: kind === "d" };
        });

        entries.sort((a, b) => {
          if (a.isDir !== b.isDir)
            return a.isDir ? -1 : 1;
          return a.name.localeCompare(b.name);
        });

        launcher.dirEntries = entries;
        launcher.recomputeResults();
      }
    }
  }

  function loadDirectory(path) {
    dirProc.command = [
      "bash", "-c",
      "find \"$1\" -maxdepth 1 -mindepth 1 -printf '%y\\t%f\\n' 2>/dev/null",
      "bash",
      path
    ];
    dirProc.running = true;
  }

  function navigateTo(path) {
    currentDir = path;
    query = "";
    searchInput.text = "";
    resultsGrid.currentIndex = 0;
    loadDirectory(path);
  }

  function navigateUp() {
    const parts = currentDir.split("/").filter((p) => p.length > 0);
    parts.pop();
    navigateTo("/" + parts.join("/"));
  }

  function filesResults(q) {
    const needle = q.toLowerCase();
    const parentPath = currentDir === "/" ? null : "..";

    let items = [];

    if (parentPath !== null) {
      items.push({
        label: "..",
        iconSource: "",
        glyph: upGlyph,
        activate: () => launcher.navigateUp()
      });
    }

    const filtered = dirEntries.filter((entry) =>
      !needle || entry.name.toLowerCase().indexOf(needle) !== -1
    );

    for (const entry of filtered) {
      const fullPath = launcher.currentDir.replace(/\/$/, "") + "/" + entry.name;

      if (entry.isDir) {
        items.push({
          label: entry.name + "/",
          iconSource: resolveIcon("folder"),
          glyph: folderGlyph,
          activate: () => launcher.navigateTo(fullPath)
        });
      } else {
        items.push({
          label: entry.name,
          iconSource: resolveIcon(mimeIconGuess(entry.name)),
          glyph: fileGlyph,
          activate: () => {
            Quickshell.execDetached({ command: ["xdg-open", fullPath] });
            launcher.closeLauncher();
          }
        });
      }
    }

    return items;
  }

  // chute rápido de ícone genérico por extensão — sem chamar `file`/xdg-mime
  // por item (custaria um processo por linha da lista)
  function mimeIconGuess(name) {
    const ext = name.includes(".") ? name.split(".").pop().toLowerCase() : "";

    const images = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif"];
    const videos = ["mp4", "mkv", "webm", "mov", "avi"];
    const audio = ["mp3", "flac", "wav", "ogg", "m4a"];
    const archives = ["zip", "tar", "gz", "xz", "7z", "rar"];
    const text = ["txt", "md", "qml", "js", "ts", "py", "json", "conf", "sh", "yml", "yaml", "css", "html"];

    if (images.includes(ext)) return "image-x-generic";
    if (videos.includes(ext)) return "video-x-generic";
    if (audio.includes(ext)) return "audio-x-generic";
    if (archives.includes(ext)) return "package-x-generic";
    if (text.includes(ext)) return "text-x-generic";

    return "text-x-generic";
  }

  // =====================================================================
  // roteamento de resultados por modo
  // =====================================================================
  function recomputeResults() {
    switch (mode) {
      case "drun":
        results = drunResults(query);
        break;
      case "window":
        results = windowResults(query);
        break;
      case "files":
        results = filesResults(query);
        break;
    }

    if (resultsGrid.currentIndex >= results.length)
      resultsGrid.currentIndex = Math.max(0, results.length - 1);
  }

  function activateCurrent() {
    const item = results[resultsGrid.currentIndex];
    if (item)
      item.activate();
  }

  function moveSelection(delta) {
    if (results.length === 0)
      return;
    resultsGrid.currentIndex = Math.max(0, Math.min(resultsGrid.currentIndex + delta, results.length - 1));
  }

  // =====================================================================
  // VISUAL
  // =====================================================================

  // véu translúcido (o blur real vem do layer_rule do Hyprland)
  Rectangle {
    anchors.fill: parent
    color: launcher.colScrim
  }

  // clique fora dos itens fecha
  MouseArea {
    anchors.fill: parent
    onClicked: launcher.closeLauncher()
  }

  Item {
    id: content

    anchors.fill: parent
    opacity: launcher.reveal
    scale: 0.97 + 0.03 * launcher.reveal

    ColumnLayout {
      anchors {
        fill: parent
        leftMargin: 56
        rightMargin: 56
        topMargin: 22
        bottomMargin: 18
      }
      spacing: 12

      // ---- cabeçalho: modos | busca | ordenação ----
      RowLayout {
        Layout.fillWidth: true
        spacing: 16

        // modos (esquerda)
        Item {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: modeRow.implicitWidth
          implicitHeight: 40

          Row {
            id: modeRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
              model: launcher.modes

              Rectangle {
                required property var modelData

                width: 46
                height: 38
                radius: 19
                color: launcher.mode === modelData.id
                  ? launcher.colAccent
                  : launcher.colPill

                Text {
                  anchors.centerIn: parent
                  text: modelData.icon
                  font.family: launcher.nerdFont
                  font.pixelSize: 15
                  color: launcher.mode === modelData.id
                    ? Colors.md3.on_primary
                    : Qt.alpha(launcher.colText, 0.85)
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    launcher.switchMode(modelData.id);
                    searchInput.forceActiveFocus();
                  }
                }
              }
            }
          }
        }

        // busca (centro)
        Rectangle {
          Layout.preferredWidth: 520
          Layout.maximumWidth: 520
          Layout.fillWidth: true
          height: 44
          radius: 22
          color: launcher.colPill

          RowLayout {
            anchors {
              fill: parent
              leftMargin: 18
              rightMargin: 18
            }
            spacing: 10

            Text {
              text: "\uf002" // fa-search
              font.family: launcher.nerdFont
              font.pixelSize: 15
              color: launcher.colMuted
            }

            TextInput {
              id: searchInput

              Layout.fillWidth: true
              color: launcher.colText
              selectionColor: launcher.colAccent
              font.family: launcher.nerdFont
              font.pixelSize: 14
              clip: true

              Keys.onPressed: (event) => {
                const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                const cols = resultsGrid.columns;

                if (event.key === Qt.Key_Escape) {
                  launcher.closeLauncher();
                  event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                  launcher.moveSelection(1);
                  event.accepted = true;
                } else if (event.key === Qt.Key_Left) {
                  launcher.moveSelection(-1);
                  event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                  launcher.moveSelection(cols);
                  event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                  launcher.moveSelection(-cols);
                  event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  launcher.activateCurrent();
                  event.accepted = true;
                } else if (event.key === Qt.Key_Backspace && searchInput.text.length === 0
                    && launcher.mode === "files" && launcher.currentDir !== "/") {
                  launcher.navigateUp();
                  event.accepted = true;
                } else if (event.key === Qt.Key_Tab) {
                  const order = ["drun", "files", "window"];
                  const next = order[(order.indexOf(launcher.mode) + 1) % order.length];
                  launcher.switchMode(next);
                  event.accepted = true;
                } else if (ctrl && event.key === Qt.Key_1) {
                  launcher.switchMode("drun");
                  event.accepted = true;
                } else if (ctrl && event.key === Qt.Key_2) {
                  launcher.switchMode("files");
                  event.accepted = true;
                } else if (ctrl && event.key === Qt.Key_3) {
                  launcher.switchMode("window");
                  event.accepted = true;
                }
              }

              onTextChanged: {
                launcher.query = text;
                resultsGrid.currentIndex = 0;
                launcher.recomputeResults();
              }

              Text {
                visible: searchInput.text.length === 0
                text: launcher.placeholders[launcher.mode]
                color: Qt.alpha(launcher.colText, 0.6)
                font: searchInput.font
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }

        // ordenação (direita) — só no modo Apps
        Item {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: sortRow.implicitWidth + 8
          implicitHeight: 40

          Rectangle {
            visible: launcher.mode === "drun"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: sortRow.implicitWidth + 8
            height: 38
            radius: 19
            color: launcher.colPill

            Row {
              id: sortRow
              anchors.centerIn: parent
              spacing: 4

              Repeater {
                model: launcher.sortOptions

                Rectangle {
                  required property var modelData

                  width: chipLabel.implicitWidth + 28
                  height: 30
                  radius: 15
                  color: launcher.sortMode === modelData.id
                    ? launcher.colAccent
                    : "transparent"

                  Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: modelData.label
                    font.family: launcher.nerdFont
                    font.pixelSize: 12
                    color: launcher.sortMode === modelData.id
                      ? Colors.md3.on_primary
                      : Qt.alpha(launcher.colText, 0.85)
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      launcher.setSortMode(modelData.id);
                      searchInput.forceActiveFocus();
                    }
                  }
                }
              }
            }
          }
        }
      }

      // ---- diretório atual (só no modo Files) ----
      Text {
        visible: launcher.mode === "files"
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: launcher.currentDir
        elide: Text.ElideMiddle
        color: launcher.colMuted
        font.family: launcher.nerdFont
        font.pixelSize: 11
      }

      // ---- grade de resultados ----
      GridView {
        id: resultsGrid

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: 6

        readonly property int columns: Math.max(4, Math.floor(width / 150))

        cellWidth: Math.floor(width / columns)
        cellHeight: 124
        clip: true
        model: launcher.results
        currentIndex: 0
        boundsBehavior: Flickable.StopAtBounds

        // scroll acompanha a seleção feita via teclado
        onCurrentIndexChanged: resultsGrid.positionViewAtIndex(
          resultsGrid.currentIndex, GridView.Contain
        )

        // clique no espaço vazio entre os itens também fecha
        MouseArea {
          z: -1
          width: resultsGrid.width
          height: Math.max(resultsGrid.contentHeight, resultsGrid.height)
          onClicked: launcher.closeLauncher()
        }

        delegate: Item {
          id: cell

          required property var modelData
          required property int index

          readonly property bool selected: index === resultsGrid.currentIndex

          width: resultsGrid.cellWidth
          height: resultsGrid.cellHeight

          Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 16
            color: cell.selected ? Qt.alpha(launcher.colAccent, 0.30) : "transparent"
            border.width: cell.selected ? 1 : 0
            border.color: Qt.alpha(launcher.colAccent, 0.80)
          }

          ColumnLayout {
            anchors {
              fill: parent
              margins: 10
            }
            spacing: 8

            Item {
              Layout.alignment: Qt.AlignHCenter
              Layout.preferredWidth: 60
              Layout.preferredHeight: 60

              IconImage {
                anchors.fill: parent
                visible: !!cell.modelData.iconSource
                source: cell.modelData.iconSource || ""
                implicitSize: 60
              }

              Text {
                anchors.centerIn: parent
                visible: !cell.modelData.iconSource
                text: cell.modelData.glyph || ""
                font.family: launcher.nerdFont
                font.pixelSize: 38
                color: launcher.colText
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.fillHeight: true
              text: cell.modelData.label
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignTop
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
              font.family: launcher.nerdFont
              font.pixelSize: 13
              color: launcher.colText
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // onPositionChanged (e não onEntered) pra o scroll não roubar
            // a seleção quando a lista se mexe debaixo do mouse parado
            onPositionChanged: resultsGrid.currentIndex = cell.index
            onClicked: {
              resultsGrid.currentIndex = cell.index;
              launcher.activateCurrent();
            }
          }
        }
      }

      Text {
        visible: launcher.results.length === 0
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        horizontalAlignment: Text.AlignHCenter
        text: "Nenhum resultado"
        color: launcher.colMuted
        font.family: launcher.nerdFont
        font.pixelSize: 13
      }
    }
  }
}
