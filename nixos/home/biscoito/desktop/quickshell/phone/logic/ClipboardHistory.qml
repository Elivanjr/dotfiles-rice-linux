// logic/ClipboardHistory.qml — Histórico da área de transferência (cliphist)
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "clip".
// Acesso de fora:  phone.clip.<membro>
// Tela: views/ClipboardView.qml
//
// Backend: cliphist list / cliphist decode / wl-copy
// (o histórico em si é alimentado por `wl-paste --watch cliphist store`)
//
// Baseado no ClipboardPanel.qml da topbar: busca, lista, miniaturas de imagem
// geradas uma de cada vez e copiar de volta. A coluna de preview virou a
// tela "preview" (softkey Ver / seta direita).
//
// Fluxo: list <-> preview

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  property string clipStage: "list"           // list | preview

  property var clipEntries: []                // [{ id, preview, label, line, isImage, ext }]

  property string clipFilter: ""

  property int clipSel: 0

  property string clipStatus: ""

  property string clipError: ""

  // id -> "file://..." (pronta) | "" (na fila) | "fail" (não deu)
  property var clipThumbs: ({})

  property var clipQueue: []

  property bool clipThumbBusy: false

  property string clipPreviewText: ""

  readonly property int clipThumbLimit: 40    // miniaturas geradas de antemão

  // runtime dir é por usuário (0700); cai para /tmp só se não existir
  readonly property string clipDir:
    (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-phone-clip"

  readonly property var clipFiltered: {
    if (clipFilter.length === 0)
      return clipEntries;

    const q = clipFilter.toLowerCase();

    return clipEntries.filter(e => e.preview.toLowerCase().indexOf(q) !== -1);
  }

  readonly property var clipCurrent:
    (clipSel >= 0 && clipSel < clipFiltered.length) ? clipFiltered[clipSel] : null

  onClipFilteredChanged: clipSel = clipFiltered.length > 0 ? 0 : -1

  onClipCurrentChanged: {
    if (clipCurrent && clipCurrent.isImage)
      clipEnsureThumb(clipCurrent);
  }

  // ---------------- textos ----------------

  readonly property string clipTitle:
    clipStage === "preview" ? "Ver" : "Clipboard"

  readonly property string clipSubtitle: {
    if (clipStage === "preview")
      return clipCurrent ? (clipCurrent.isImage ? "Imagem" : "Texto") : "";

    if (clipError !== "")
      return "Sem histórico";

    if (clipEntries.length === 0)
      return "Histórico vazio";

    if (clipFilter.length > 0)
      return clipFiltered.length + " de " + clipEntries.length + " itens";

    return clipEntries.length + (clipEntries.length === 1 ? " item" : " itens");
  }

  readonly property string clipSoftLeft:
    (clipStage === "list" && clipCurrent) ? "Ver" : ""

  readonly property string clipSoftCenter:
    clipCurrent ? "Copiar" : ""

  readonly property string clipSoftRight:
    clipStage === "preview" ? "Fechar" : "Voltar"

  // ---------------- lista ----------------

  function clipEnter() {
    clipStage = "list";
    clipFilter = "";
    clipStatus = "";
    clipError = "";
    clipSel = 0;
    clipRefresh();
  }

  function clipRefresh() {
    if (clipListProc.running)
      return;

    clipListProc.running = true;
  }

  function clipParse(text) {
    const lines = text.split("\n").filter(l => l.length > 0);
    const list = [];

    for (const line of lines) {
      const tab = line.indexOf("\t");

      if (tab === -1)
        continue;

      const id = line.substring(0, tab);
      const preview = line.substring(tab + 1);

      // "[[ binary data 1.2 MiB png 1920x1080 ]]"
      const img = /^\[\[ binary data (.*?)\s(png|jpe?g|gif|bmp|webp)\b\s*(\d+x\d+)?/i.exec(preview);

      let label = preview;

      if (img)
        label = "Imagem · " + img[2].toLowerCase() + " · " + img[1] + (img[3] ? " · " + img[3] : "");

      list.push({
        id: id,
        preview: preview,
        label: label,
        line: line,
        isImage: img !== null,
        ext: img ? img[2].toLowerCase().replace("jpeg", "jpg") : ""
      });
    }

    if (list.length > 0)
      clipError = "";

    clipEntries = list;
    clipQueueFirst();
  }

  function clipMove(d) {
    const n = clipFiltered.length;

    if (n === 0)
      return;

    clipSel = Math.max(0, Math.min(n - 1, clipSel + d));
  }

  function clipType(str) {
    if (!str)
      return;

    clipFilter = (clipFilter + str).slice(0, 60);
    clipStatus = "";
  }

  // ---------------- miniaturas (fila sequencial) ----------------

  // as primeiras imagens da lista, até o limite
  function clipQueueFirst() {
    const q = [];

    for (const e of clipEntries) {
      if (q.length >= clipThumbLimit)
        break;

      if (!e.isImage || clipThumbs[e.id] !== undefined)
        continue;

      clipThumbs[e.id] = "";
      q.push(e);
    }

    clipQueue = clipQueue.concat(q);
    clipProcessQueue();
  }

  // a imagem selecionada passa na frente da fila
  function clipEnsureThumb(entry) {
    const cur = clipThumbs[entry.id];

    if (cur !== undefined && cur !== "")
      return;

    clipQueue = clipQueue.filter(e => e.id !== entry.id);
    clipQueue.unshift(entry);
    clipThumbs[entry.id] = "";
    clipProcessQueue();
  }

  // URL da miniatura (ou "" se ainda não ficou pronta / falhou)
  function clipThumbSrc(id) {
    const v = clipThumbs[id];

    return (v !== undefined && v !== "" && v !== "fail") ? v : "";
  }

  function clipProcessQueue() {
    if (clipThumbBusy || clipQueue.length === 0)
      return;

    clipThumbBusy = true;

    const entry = clipQueue.shift();

    clipThumbProc.targetId = entry.id;
    clipThumbProc.targetPath = clipDir + "/" + entry.id + "." + (entry.ext || "png");
    clipThumbProc.command = [
      "bash", "-c",
      'umask 077; mkdir -p "$3" && printf "%s" "$1" | cliphist decode > "$2"',
      "--",
      entry.line,
      clipThumbProc.targetPath,
      clipDir
    ];

    clipThumbProc.running = true;
  }

  function clipOnThumbDone(code) {
    const m = Object.assign({}, clipThumbs);

    m[clipThumbProc.targetId] = code === 0 ? "file://" + clipThumbProc.targetPath : "fail";
    clipThumbs = m;
    clipThumbBusy = false;
    clipProcessQueue();
  }

  // ---------------- copiar ----------------

  function clipCopy(entry) {
    if (!entry || clipCopyProc.running)
      return;

    clipCopyProc.command = [
      "bash", "-c",
      'printf "%s" "$1" | cliphist decode | wl-copy',
      "--",
      entry.line
    ];

    clipCopyProc.running = true;
    clipStatus = "Copiado: " + (entry.isImage ? "imagem" : entry.preview.slice(0, 40));
  }

  // ---------------- ver ----------------

  function clipOpenPreview() {
    const e = clipCurrent;

    if (!e)
      return;

    clipStage = "preview";
    clipPreviewText = "";

    if (e.isImage) {
      clipEnsureThumb(e);
      return;
    }

    if (clipTextProc.running)
      clipTextProc.running = false;

    clipTextProc.command = [
      "bash", "-c",
      'printf "%s" "$1" | cliphist decode | head -c 6000',
      "--",
      e.line
    ];

    clipTextProc.running = true;
  }

  function clipClosePreview() {
    clipStage = "list";
  }

  // ---------------- teclado ----------------

  function handleClipKey(e) {
    let ok = false;

    if (clipStage === "preview")
      ok = clipPreviewKey(e);
    else
      ok = clipListKey(e);

    if (ok)
      e.accepted = true;
  }

  function clipListKey(e) {
    switch (e.key) {
    case Qt.Key_Escape:
      if (clipFilter !== "")
        clipFilter = "";
      else
        phone.view = "menu";

      return true;

    case Qt.Key_Up:       clipMove(-1); return true;
    case Qt.Key_Down:     clipMove(1);  return true;
    case Qt.Key_PageUp:   clipMove(-5); return true;
    case Qt.Key_PageDown: clipMove(5);  return true;

    case Qt.Key_Right:
      clipOpenPreview();
      return true;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      clipCopy(clipCurrent);
      return true;

    case Qt.Key_Backspace:
      clipFilter = clipFilter.slice(0, -1);
      return true;

    default:
      if (e.text && e.text.length === 1 && e.text >= " ") {
        clipType(e.text);
        return true;
      }

      return false;
    }
  }

  function clipPreviewKey(e) {
    switch (e.key) {
    case Qt.Key_Escape:
    case Qt.Key_Left:
    case Qt.Key_Backspace:
      clipClosePreview();
      return true;

    case Qt.Key_Up:
      clipMove(-1);
      clipOpenPreview();
      return true;

    case Qt.Key_Down:
      clipMove(1);
      clipOpenPreview();
      return true;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      clipCopy(clipCurrent);
      return true;

    default:
      return false;
    }
  }

  // ---------------- softkeys (chamadas pelo KeyControls) ----------------

  function clipLeftKey() {
    if (clipStage === "list")
      clipOpenPreview();
  }

  function clipCenterKey() {
    clipCopy(clipCurrent);
  }

  function clipBack() {
    if (clipStage === "preview")
      clipClosePreview();
    else
      phone.view = "menu";
  }

  // ---------------- processos ----------------

  Process {
    id: clipListProc

    command: ["cliphist", "list"]

    stdout: StdioCollector {
      onStreamFinished: phone.clip.clipParse(this.text)
    }

    onExited: (code, status) => {
      if (code !== 0) {
        phone.clip.clipEntries = [];
        phone.clip.clipError = "Não consegui rodar o cliphist. Ele está instalado e o `wl-paste --watch cliphist store` está ativo?";
      }
    }
  }

  Process {
    id: clipThumbProc

    property string targetId: ""
    property string targetPath: ""

    onExited: (code, status) => phone.clip.clipOnThumbDone(code)
  }

  Process {
    id: clipCopyProc
  }

  Process {
    id: clipTextProc

    stdout: StdioCollector {
      onStreamFinished: {
        if (phone.clip.clipStage === "preview")
          phone.clip.clipPreviewText = this.text;
      }
    }
  }
}
