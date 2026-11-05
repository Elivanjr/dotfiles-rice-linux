// ClipboardPanel.qml — histórico de clipboard (cliphist) com preview de
// imagem, no estilo do menu do Dank Material Shell.
//
// Backend: cliphist list / cliphist decode / wl-copy
//
// Thumbnails: gerados sob demanda, um de cada vez (fila sequencial), só
// pras entradas de imagem realmente visíveis na lista.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../theme"

PanelWindow {
  id: clipPanel

  required property var screenRef
  screen: screenRef

  property bool panelOpen: false
  visible: panelOpen

  color: "transparent"
  focusable: true

  // "focusable: true" sozinho usa o modo OnDemand do wlr-layer-shell, que
  // só garante foco de teclado quando o mouse já passou pela janela antes.
  // Exclusive garante foco de teclado enquanto o painel estiver aberto.
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  signal closeRequested()

  anchors {
    top: true
    left: true
  }

  implicitWidth: 900
  implicitHeight: 460

  margins.top: Math.round((screenRef.height - implicitHeight) / 2)
  margins.left: Math.round((screenRef.width - implicitWidth) / 2)

  property int currentIndex: 0

  // ================================================================
  // CORES — MATUGEN
  // ================================================================

  // Converte uma cor hexadecimal do Colors.qml em rgba com alpha.
  //
  // Exemplo:
  //   matugenColor(Colors.md3.primary, 0.15)
  //
  // Isso permite preservar as transparências que existiam no painel
  // original sem precisar colocar cores RGB fixas aqui.
  function matugenColor(hex, alpha) {
    let value = hex;

    if (value.startsWith("#")) {
      value = value.substring(1);
    }

    if (value.length === 8) {
      // #AARRGGBB
      const a = parseInt(value.substring(0, 2), 16) / 255;
      const r = parseInt(value.substring(2, 4), 16) / 255;
      const g = parseInt(value.substring(4, 6), 16) / 255;
      const b = parseInt(value.substring(6, 8), 16) / 255;

      return Qt.rgba(r, g, b, a * alpha);
    }

    // #RRGGBB
    const r = parseInt(value.substring(0, 2), 16) / 255;
    const g = parseInt(value.substring(2, 4), 16) / 255;
    const b = parseInt(value.substring(4, 6), 16) / 255;

    return Qt.rgba(r, g, b, alpha);
  }

  onPanelOpenChanged: {
    if (panelOpen) {
      filterText = "";
      searchField.text = "";
      previewEntry = null;
      currentIndex = 0;
      refreshProc.running = true;
      card.forceActiveFocus();
      searchField.forceActiveFocus();
    }
  }

  onFilteredEntriesChanged:
    currentIndex = filteredEntries.length > 0 ? 0 : -1

  property var entries: []
  property string filterText: ""

  readonly property var filteredEntries: {
    if (filterText.length === 0)
      return entries;

    const q = filterText.toLowerCase();

    return entries.filter(
      e => e.preview.toLowerCase().indexOf(q) !== -1
    );
  }

  // Entrada de imagem atualmente sob o mouse.
  property var previewEntry: null

  // id -> "file://..." (pronto)
  //    -> ""            (pendente)
  //    -> undefined     (nunca pedido)
  property var thumbCache: ({})
  property var thumbQueue: []
  property bool thumbBusy: false

  readonly property int thumbLimit: 40

  // ================================================================
  // CLIPHIST LIST
  // ================================================================

  Process {
    id: refreshProc

    command: ["cliphist", "list"]

    stdout: StdioCollector {
      onStreamFinished: {
        const lines = this.text
          .split("\n")
          .filter(l => l.length > 0);

        const list = [];

        for (const line of lines) {
          const tabIdx = line.indexOf("\t");

          if (tabIdx === -1)
            continue;

          const id = line.substring(0, tabIdx);
          const preview = line.substring(tabIdx + 1);

          const imgMatch =
            /^\[\[ binary data .*?\s(png|jpe?g|gif|bmp|webp)\b/i.exec(
              preview
            );

          list.push({
            id: id,
            preview: preview,
            line: line,
            isImage: imgMatch !== null,
            ext: imgMatch ? imgMatch[1].toLowerCase() : ""
          });
        }

        clipPanel.entries = list;
        clipPanel.queueThumbnails();
      }
    }
  }

  function queueThumbnails() {
    const queue = [];
    let count = 0;

    for (const e of clipPanel.entries) {
      if (!e.isImage)
        continue;

      if (clipPanel.thumbCache[e.id] !== undefined)
        continue;

      if (count >= clipPanel.thumbLimit)
        break;

      clipPanel.thumbCache[e.id] = "";
      queue.push(e);
      count++;
    }

    clipPanel.thumbQueue =
      clipPanel.thumbQueue.concat(queue);

    clipPanel.processThumbQueue();
  }

  // Chamado ao passar o mouse numa entrada de imagem.
  function requestPreview(entry) {
    clipPanel.previewEntry = entry;

    if (
      clipPanel.thumbCache[entry.id] !== undefined &&
      clipPanel.thumbCache[entry.id] !== ""
    ) {
      return;
    }

    clipPanel.thumbQueue =
      clipPanel.thumbQueue.filter(e => e.id !== entry.id);

    clipPanel.thumbQueue.unshift(entry);
    clipPanel.thumbCache[entry.id] = "";

    clipPanel.processThumbQueue();
  }

  function processThumbQueue() {
    if (
      clipPanel.thumbBusy ||
      clipPanel.thumbQueue.length === 0
    ) {
      return;
    }

    clipPanel.thumbBusy = true;

    const entry = clipPanel.thumbQueue.shift();

    const path =
      "/tmp/qs-clip-" +
      entry.id +
      "." +
      (entry.ext || "png");

    thumbProc.targetId = entry.id;
    thumbProc.targetPath = path;

    thumbProc.command = [
      "bash",
      "-c",
      'printf "%s" "$1" | cliphist decode > "$2"',
      "--",
      entry.line,
      path
    ];

    thumbProc.running = true;
  }

  Process {
    id: thumbProc

    property string targetId: ""
    property string targetPath: ""

    stdout: StdioCollector {
      onStreamFinished: {
        const cache = clipPanel.thumbCache;

        cache[thumbProc.targetId] =
          "file://" + thumbProc.targetPath;

        clipPanel.thumbCache =
          Object.assign({}, cache);

        clipPanel.thumbBusy = false;
        clipPanel.processThumbQueue();
      }
    }
  }

  // ================================================================
  // COPIAR
  // ================================================================

  Process {
    id: copyProc
  }

  function copyEntry(entry) {
    copyProc.command = [
      "bash",
      "-c",
      'printf "%s" "$1" | cliphist decode | wl-copy',
      "--",
      entry.line
    ];

    copyProc.running = true;
    clipPanel.closeRequested();
  }

  // ================================================================
  // PAINEL
  // ================================================================

  Rectangle {
    id: card

    anchors.fill: parent

    radius: 16

    // Antes:
    // Qt.rgba(0.05, 0.06, 0.05, 0.96)
    //
    // Agora:
    // surface do Material You gerado pelo Matugen.
    color: clipPanel.matugenColor(
      Colors.md3.surface,
      0.96
    )

    border.color: clipPanel.matugenColor(
      Colors.md3.outline,
      0.06
    )

    border.width: 1

    focus: true

    Keys.onEscapePressed:
      clipPanel.closeRequested()

    RowLayout {
      anchors.fill: parent
      anchors.margins: 14
      spacing: 14

      // ============================================================
      // COLUNA ESQUERDA
      // ============================================================

      ColumnLayout {
        Layout.preferredWidth: 400
        Layout.minimumWidth: 400
        Layout.maximumWidth: 400
        Layout.fillWidth: false
        Layout.fillHeight: true

        spacing: 10

        // ----------------------------------------------------------
        // BUSCA
        // ----------------------------------------------------------

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 34

          radius: 8

          color: clipPanel.matugenColor(
            Colors.md3.surface_container,
            0.65
          )

          RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Text {
              text: "\u{F002}"

              color: Colors.md3.outline

              font.pixelSize: 12
            }

            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              TextInput {
                id: searchField

                anchors.fill: parent

                color: Colors.md3.on_surface

                font.family: "JetBrainsMono NF"
                font.pixelSize: 12

                verticalAlignment:
                  TextInput.AlignVCenter

                clip: true

                onTextChanged:
                  clipPanel.filterText = text

                Keys.onEscapePressed:
                  clipPanel.closeRequested()

                Keys.onDownPressed: {
                  if (
                    clipPanel.filteredEntries.length === 0
                  ) {
                    return;
                  }

                  clipPanel.currentIndex =
                    Math.min(
                      clipPanel.currentIndex + 1,
                      clipPanel.filteredEntries.length - 1
                    );

                  listView.positionViewAtIndex(
                    clipPanel.currentIndex,
                    ListView.Contain
                  );

                  const entry =
                    clipPanel.filteredEntries[
                      clipPanel.currentIndex
                    ];

                  if (entry.isImage) {
                    clipPanel.requestPreview(entry);
                  }
                }

                Keys.onUpPressed: {
                  if (
                    clipPanel.filteredEntries.length === 0
                  ) {
                    return;
                  }

                  clipPanel.currentIndex =
                    Math.max(
                      clipPanel.currentIndex - 1,
                      0
                    );

                  listView.positionViewAtIndex(
                    clipPanel.currentIndex,
                    ListView.Contain
                  );

                  const entry =
                    clipPanel.filteredEntries[
                      clipPanel.currentIndex
                    ];

                  if (entry.isImage) {
                    clipPanel.requestPreview(entry);
                  }
                }

                Keys.onReturnPressed: {
                  if (
                    clipPanel.currentIndex >= 0 &&
                    clipPanel.currentIndex <
                      clipPanel.filteredEntries.length
                  ) {
                    clipPanel.copyEntry(
                      clipPanel.filteredEntries[
                        clipPanel.currentIndex
                      ]
                    );
                  }
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter

                text: "Buscar..."

                color: Colors.md3.outline

                font.family: "JetBrainsMono NF"
                font.pixelSize: 12

                visible:
                  searchField.text.length === 0
              }
            }
          }
        }

        // ----------------------------------------------------------
        // LISTA
        // ----------------------------------------------------------

        ListView {
          id: listView

          Layout.fillWidth: true
          Layout.fillHeight: true

          clip: true
          spacing: 4

          model: clipPanel.filteredEntries

          delegate: Rectangle {
            id: rowDelegate

            required property var modelData
            required property int index

            width: listView.width

            height:
              modelData.isImage
                ? 64
                : 32

            radius: 8

            color:
              (
                rowHover.containsMouse ||
                clipPanel.currentIndex === index
              )
                ? clipPanel.matugenColor(
                    Colors.md3.primary,
                    0.15
                  )
                : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.margins: 6

              spacing: 8

              Rectangle {
                visible:
                  rowDelegate.modelData.isImage

                Layout.preferredWidth: 52
                Layout.preferredHeight: 52

                radius: 6

                color: clipPanel.matugenColor(
                  Colors.md3.surface_container,
                  0.8
                )

                clip: true

                Image {
                  anchors.fill: parent

                  source:
                    clipPanel.thumbCache[
                      rowDelegate.modelData.id
                    ] || ""

                  fillMode:
                    Image.PreserveAspectCrop

                  asynchronous: true
                }
              }

              Text {
                text:
                  rowDelegate.modelData.preview

                color:
                  Colors.md3.on_surface

                font.family:
                  "JetBrainsMono NF"

                font.pixelSize: 11

                elide:
                  Text.ElideRight

                Layout.fillWidth: true
              }
            }

            MouseArea {
              id: rowHover

              anchors.fill: parent

              hoverEnabled: true

              onClicked:
                clipPanel.copyEntry(
                  rowDelegate.modelData
                )

              onEntered: {
                clipPanel.currentIndex =
                  rowDelegate.index;

                if (
                  rowDelegate.modelData.isImage
                ) {
                  clipPanel.requestPreview(
                    rowDelegate.modelData
                  );
                }
              }
            }
          }
        }
      }

      // ============================================================
      // COLUNA DIREITA — PREVIEW
      // ============================================================

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 200

        radius: 12

        color: clipPanel.matugenColor(
          Colors.md3.surface_container,
          0.35
        )

        border.color: clipPanel.matugenColor(
          Colors.md3.primary,
          0.25
        )

        border.width: 1

        clip: true

        Image {
          anchors.fill: parent
          anchors.margins: 10

          visible:
            clipPanel.previewEntry !== null

          source:
            clipPanel.previewEntry
              ? (
                  clipPanel.thumbCache[
                    clipPanel.previewEntry.id
                  ] || ""
                )
              : ""

          fillMode:
            Image.PreserveAspectFit

          asynchronous: true
        }

        Text {
          anchors.centerIn: parent

          visible:
            clipPanel.previewEntry === null

          text:
            ""

          horizontalAlignment:
            Text.AlignHCenter

          color:
            Colors.md3.outline

          font.family:
            "JetBrainsMono NF"

          font.pixelSize: 11
        }
      }
    }
  }
}
