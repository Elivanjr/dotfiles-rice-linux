// ClipboardPanel.qml — histórico de clipboard (cliphist) com preview de
// imagem, no estilo do menu do Dank Material Shell.
//
// Backend: cliphist list / cliphist decode / wl-copy (o mesmo pipeline que
// já era usado no script de rofi do usuário). Nada de stdin via API do
// Quickshell — a linha do cliphist vira argumento posicional pro bash
// (`-- "$1"`), que é seguro mesmo se o conteúdo copiado tiver aspas, $,
// crase etc.
//
// Thumbnails: gerados sob demanda, um de cada vez (fila sequencial), só
// pras entradas de imagem realmente visíveis na lista — evita disparar uma
// rajada de `cliphist decode` pra um histórico gigante de uma vez.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
  id: clipPanel
  required property var screenRef
  screen: screenRef
  property bool panelOpen: false
  visible: panelOpen
  color: "transparent"
  focusable: true
  // "focusable: true" sozinho usa o modo OnDemand do wlr-layer-shell, que
  // só garante foco de teclado quando o mouse já passou pela janela antes
  // (por isso o Esc só funcionava com o cursor em cima). Exclusive trava o
  // teclado nessa janela enquanto ela estiver aberta, sem essa pegadinha.
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  signal closeRequested()

  anchors { top: true; left: true }
  implicitWidth: 900
  implicitHeight: 460
  margins.top: Math.round((screenRef.height - implicitHeight) / 2)
  margins.left: Math.round((screenRef.width - implicitWidth) / 2)

  property int currentIndex: 0

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

  onFilteredEntriesChanged: currentIndex = filteredEntries.length > 0 ? 0 : -1

  property var entries: [] // [{id, preview, line, isImage, ext}]
  property string filterText: ""
  readonly property var filteredEntries: {
    if (filterText.length === 0) return entries;
    const q = filterText.toLowerCase();
    return entries.filter(e => e.preview.toLowerCase().indexOf(q) !== -1);
  }

  // entrada de imagem atualmente sob o mouse — mostrada em tamanho grande
  // no painel da direita
  property var previewEntry: null

  // id -> "file://..." (pronto) | "" (pendente) | undefined (nunca pedido)
  property var thumbCache: ({})
  property var thumbQueue: []
  property bool thumbBusy: false
  readonly property int thumbLimit: 40 // não gera thumb pra história inteira de uma vez

  // ---------- lista (cliphist list) ----------
  Process {
    id: refreshProc
    command: ["cliphist", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = this.text.split("\n").filter(l => l.length > 0);
        const list = [];
        for (const line of lines) {
          const tabIdx = line.indexOf("\t");
          if (tabIdx === -1) continue;
          const id = line.substring(0, tabIdx);
          const preview = line.substring(tabIdx + 1);
          const imgMatch = /^\[\[ binary data .*?\s(png|jpe?g|gif|bmp|webp)\b/i.exec(preview);
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
      if (!e.isImage) continue;
      if (clipPanel.thumbCache[e.id] !== undefined) continue;
      if (count >= clipPanel.thumbLimit) break;
      clipPanel.thumbCache[e.id] = "";
      queue.push(e);
      count++;
    }
    clipPanel.thumbQueue = clipPanel.thumbQueue.concat(queue);
    clipPanel.processThumbQueue();
  }

  // chamado ao passar o mouse numa entrada de imagem — se ela ainda não
  // tem thumb pronto, fura a fila em vez de esperar a ordem normal
  function requestPreview(entry) {
    clipPanel.previewEntry = entry;
    if (clipPanel.thumbCache[entry.id] !== undefined && clipPanel.thumbCache[entry.id] !== "") return;
    clipPanel.thumbQueue = clipPanel.thumbQueue.filter(e => e.id !== entry.id);
    clipPanel.thumbQueue.unshift(entry);
    clipPanel.thumbCache[entry.id] = "";
    clipPanel.processThumbQueue();
  }

  function processThumbQueue() {
    if (clipPanel.thumbBusy || clipPanel.thumbQueue.length === 0) return;
    clipPanel.thumbBusy = true;
    const entry = clipPanel.thumbQueue.shift();
    const path = "/tmp/qs-clip-" + entry.id + "." + (entry.ext || "png");
    thumbProc.targetId = entry.id;
    thumbProc.targetPath = path;
    thumbProc.command = ["bash", "-c", 'printf "%s" "$1" | cliphist decode > "$2"', "--", entry.line, path];
    thumbProc.running = true;
  }

  Process {
    id: thumbProc
    property string targetId: ""
    property string targetPath: ""
    stdout: StdioCollector {
      onStreamFinished: {
        const cache = clipPanel.thumbCache;
        cache[thumbProc.targetId] = "file://" + thumbProc.targetPath;
        clipPanel.thumbCache = Object.assign({}, cache);
        clipPanel.thumbBusy = false;
        clipPanel.processThumbQueue();
      }
    }
  }

  // ---------- copiar (cliphist decode | wl-copy) ----------
  Process { id: copyProc }

  function copyEntry(entry) {
    copyProc.command = ["bash", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "--", entry.line];
    copyProc.running = true;
    clipPanel.closeRequested();
  }

  Rectangle {
    id: card
    anchors.fill: parent
    radius: 16
    color: Qt.rgba(0.05, 0.06, 0.05, 0.96)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1

    focus: true
    Keys.onEscapePressed: clipPanel.closeRequested()

    RowLayout {
      anchors.fill: parent
      anchors.margins: 14
      spacing: 14

      // ===================== COLUNA ESQUERDA: busca + lista =====================
      ColumnLayout {
        Layout.preferredWidth: 400
        Layout.minimumWidth: 400
        Layout.maximumWidth: 400
        Layout.fillWidth: false
        Layout.fillHeight: true
        spacing: 10

        // ---- busca ----
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 34
          radius: 8
          color: Qt.rgba(1, 1, 1, 0.06)

          RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Text {
              text: "\u{F002}" // lupa (fa-search)
              color: "#9aa08f"
              font.pixelSize: 12
            }

            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              TextInput {
                id: searchField
                anchors.fill: parent
                color: "#f2f0ea"
                font.family: "JetBrainsMono NF"
                font.pixelSize: 12
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                onTextChanged: clipPanel.filterText = text
                Keys.onEscapePressed: clipPanel.closeRequested()
                Keys.onDownPressed: {
                  if (clipPanel.filteredEntries.length === 0) return;
                  clipPanel.currentIndex = Math.min(clipPanel.currentIndex + 1, clipPanel.filteredEntries.length - 1);
                  listView.positionViewAtIndex(clipPanel.currentIndex, ListView.Contain);
                }
                Keys.onUpPressed: {
                  if (clipPanel.filteredEntries.length === 0) return;
                  clipPanel.currentIndex = Math.max(clipPanel.currentIndex - 1, 0);
                  listView.positionViewAtIndex(clipPanel.currentIndex, ListView.Contain);
                }
                Keys.onReturnPressed: {
                  if (clipPanel.currentIndex >= 0 && clipPanel.currentIndex < clipPanel.filteredEntries.length) {
                    clipPanel.copyEntry(clipPanel.filteredEntries[clipPanel.currentIndex]);
                  }
                }
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Buscar..."
                color: "#9aa08f"
                font.family: "JetBrainsMono NF"
                font.pixelSize: 12
                visible: searchField.text.length === 0
              }
            }
          }
        }

        // ---- lista ----
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
            height: modelData.isImage ? 64 : 32
            radius: 8
            color: (rowHover.containsMouse || clipPanel.currentIndex === index)
                   ? Qt.rgba(0.56, 0.75, 0.42, 0.15) : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.margins: 6
              spacing: 8

              Rectangle {
                visible: rowDelegate.modelData.isImage
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: 6
                color: Qt.rgba(0, 0, 0, 0.3)
                clip: true

                Image {
                  anchors.fill: parent
                  source: clipPanel.thumbCache[rowDelegate.modelData.id] || ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                }
              }

              Text {
                text: rowDelegate.modelData.preview
                color: "#f2f0ea"
                font.family: "JetBrainsMono NF"
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }

            MouseArea {
              id: rowHover
              anchors.fill: parent
              hoverEnabled: true
              onClicked: clipPanel.copyEntry(rowDelegate.modelData)
              onEntered: {
                clipPanel.currentIndex = rowDelegate.index;
                if (rowDelegate.modelData.isImage) clipPanel.requestPreview(rowDelegate.modelData);
              }
            }
          }
        }
      }

      // ===================== COLUNA DIREITA: preview grande =====================
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 200
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.03)
        border.color: Qt.rgba(0.56, 0.75, 0.42, 0.25)
        border.width: 1
        clip: true

        Image {
          anchors.fill: parent
          anchors.margins: 10
          visible: clipPanel.previewEntry !== null
          source: clipPanel.previewEntry ? (clipPanel.thumbCache[clipPanel.previewEntry.id] || "") : ""
          fillMode: Image.PreserveAspectFit
          asynchronous: true
        }

        Text {
          anchors.centerIn: parent
          visible: clipPanel.previewEntry === null
          text: "passe o mouse numa imagem\npra ver o preview aqui"
          horizontalAlignment: Text.AlignHCenter
          color: "#9aa08f"
          font.family: "JetBrainsMono NF"
          font.pixelSize: 11
        }
      }
    }
  }
}
