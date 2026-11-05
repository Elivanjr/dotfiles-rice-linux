// logic/FileBrowser.qml — Meus arquivos + troca da foto de perfil
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "files".
// Acesso de fora:  phone.files.<membro>

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // item da view registrado por ela mesma (Binding em views/FilesView.qml)
  property var filesListRef: null

  // ================================================================
  // MEUS ARQUIVOS
  // ================================================================

  readonly property string homeDir: Quickshell.env("HOME")

  property string filesDir: Quickshell.env("HOME")

  property bool showHidden: false

  property var rawFiles: []

  property int filesSelected: 0

  // ".." no topo (menos na raiz), depois o conteúdo da pasta
  readonly property var fileEntries: {
    const out = [];

    if (filesDir !== "/")
      out.push({ name: "..", dir: true, up: true, size: 0 });

    for (let i = 0; i < rawFiles.length; i++) {
      const f = rawFiles[i];

      if (!showHidden && f.name.charAt(0) === ".")
        continue;

      out.push(f);
    }

    return out;
  }

  // modo "escolher foto": o navegador serve de seletor de imagem
  property bool filesPick: false

  property bool filesPickAi: false          // true = o seletor serve aos anexos da IA

  property bool filesPickUpload: false     // true = o seletor serve ao upload do SSH

  property string filesReturnView: "menu"

  property string avatarStartDir: Quickshell.env("HOME") + "/Imagens"

  property string avatarStatus: ""

  property int photoRev: 0

  function openFiles(pick) {
    filesPick = pick;
    filesPickUpload = false;
    filesPickAi = false;
    filesReturnView = pick ? "info" : "menu";

    if (pick)
      filesDir = avatarStartDir;

    phone.view = "files";
  }

  function isImage(name) {
    return /\.(png|jpe?g|webp|bmp|gif)$/i.test(name || "");
  }

  function setAvatar(path) {
    avatarProc.src = path;
    avatarStatus = "Atualizando foto...";
    filesPick = false;
    phone.view = phone.config.avatarReturn;
    phone.config.avatarReturn = "info";
    avatarProc.running = true;
  }

  Timer {
    id: avatarStatusClear

    interval: 6000
    repeat: false

    onTriggered: phone.files.avatarStatus = ""
  }

  // redimensiona p/ 512x512 (o AccountsService recusa arquivos > 1 MB) e
  // troca a foto de perfil via D-Bus (muda também a do login/SDDM)
  Process {
    id: avatarProc

    property string src: ""

    running: false

    command: ["sh", "-c", `
      src="$1"
      mkdir -p "$HOME/.cache"
      tmp="$HOME/.cache/phone-avatar.png"

      if command -v magick >/dev/null 2>&1; then
        magick "$src[0]" -resize '512x512^' -gravity center -extent 512x512 "$tmp" || exit 3
      elif command -v convert >/dev/null 2>&1; then
        convert "$src[0]" -resize '512x512^' -gravity center -extent 512x512 "$tmp" || exit 3
      else
        cp "$src" "$tmp" || exit 3
      fi

      busctl call org.freedesktop.Accounts "/org/freedesktop/Accounts/User$(id -u)" \
        org.freedesktop.Accounts.User SetIconFile s "$tmp"
    `, "sh", avatarProc.src]

    stderr: StdioCollector {
      id: avatarErr
    }

    onExited: function (code) {
      if (code === 0) {
        phone.files.photoRev += 1;
        phone.files.avatarStatus = "Foto atualizada";
      } else {
        const first = (avatarErr.text || "").split("\n")[0];

        phone.files.avatarStatus = "Falhou: " + (first || "código " + code);
      }

      avatarStatusClear.restart();
    }
  }

  function parentOf(path) {
    if (path === "/" || path === "")
      return "/";

    const k = path.lastIndexOf("/");

    return k <= 0 ? "/" : path.slice(0, k);
  }

  function joinPath(dir, name) {
    return dir === "/" ? "/" + name : dir + "/" + name;
  }

  function displayPath(p) {
    if (p === homeDir)
      return "~";

    if (p.indexOf(homeDir + "/") === 0)
      return "~" + p.slice(homeDir.length);

    return p;
  }

  function folderTitle(p) {
    if (p === homeDir)
      return "Meus arquivos";

    if (p === "/")
      return "/";

    return p.split("/").pop();
  }

  function fmtSize(b) {
    if (b < 1024)
      return b + " B";

    if (b < 1048576)
      return (b / 1024).toFixed(b < 10240 ? 1 : 0) + " KB";

    if (b < 1073741824)
      return (b / 1048576).toFixed(b < 10485760 ? 1 : 0) + " MB";

    return (b / 1073741824).toFixed(1) + " GB";
  }

  function listDir(path) {
    filesDir = path;
    filesSelected = 0;
    rawFiles = [];
    filesProc.running = true;
  }

  function goUp() {
    listDir(parentOf(filesDir));
  }

  function openEntry(entry) {
    if (!entry)
      return;

    if (entry.up) {
      goUp();
      return;
    }

    const full = joinPath(filesDir, entry.name);

    if (entry.dir) {
      listDir(full);
      return;
    }

    if (filesPick) {
      if (filesPickUpload) {
        filesPick = false;
        filesPickUpload = false;
        phone.view = "ssh";
        phone.ssh.sshUpload([full]);
      } else if (filesPickAi) {
        filesPick = false;
        filesPickAi = false;
        phone.view = "ai";
        phone.ai.aiAttach(full, true);
      } else if (isImage(entry.name)) {
        setAvatar(full);
      }

      return;
    }

    Quickshell.execDetached(["xdg-open", full]);
    phone.panelOpen = false;
  }

  function openSelectedFile() {
    openEntry(fileEntries[filesSelected]);
  }

  function moveFiles(delta) {
    const n = fileEntries.length;

    if (n === 0)
      return;

    filesSelected = Math.max(0, Math.min(n - 1, filesSelected + delta));
  }

  function handleFilesKey(e) {
    if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_H) {
      showHidden = !showHidden;
      e.accepted = true;
      return;
    }

    switch (e.key) {
    case Qt.Key_Escape:
      phone.view = filesReturnView;
      break;

    case Qt.Key_Backspace:
    case Qt.Key_Left:
      goUp();
      break;

    case Qt.Key_Right: {
      const sel = fileEntries[filesSelected];

      if (sel && sel.dir)
        openEntry(sel);

      break;
    }

    case Qt.Key_Return:
    case Qt.Key_Enter:
      openSelectedFile();
      break;

    case Qt.Key_Up:       moveFiles(-1); break;
    case Qt.Key_Down:     moveFiles(1);  break;
    case Qt.Key_PageUp:   moveFiles(-8); break;
    case Qt.Key_PageDown: moveFiles(8);  break;

    default:
      return;
    }

    e.accepted = true;
  }

  onFilesSelectedChanged: {
    if (phone.view === "files")
      filesListRef?.positionViewAtIndex(filesSelected, ListView.Contain);
  }

  // se o resultado for de uma pasta antiga (navegou rápido), relê
  Timer {
    id: filesRetry

    interval: 80
    repeat: false

    onTriggered: filesProc.running = true
  }

  Process {
    id: filesProc

    running: false

    // 1ª linha: a pasta lida; depois: tipo<TAB>tamanho<TAB>nome
    command: ["sh", "-c", `
      printf '%s\n' "$1"
      find "$1" -mindepth 1 -maxdepth 1 -printf '%Y\t%s\t%f\n' 2>/dev/null
    `, "sh", phone.files.filesDir]

    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n");

        if (lines[0] !== phone.files.filesDir) {
          filesRetry.restart();
          return;
        }

        const items = [];

        for (let i = 1; i < lines.length; i++) {
          const l = lines[i];

          if (!l)
            continue;

          const a = l.indexOf("\t");
          const b = l.indexOf("\t", a + 1);

          if (a < 0 || b < 0)
            continue;

          items.push({
            dir: l.slice(0, a) === "d",
            size: parseInt(l.slice(a + 1, b)) || 0,
            name: l.slice(b + 1)
          });
        }

        // pastas primeiro, depois ordem alfabética sem diferenciar maiúsculas
        items.sort(function (x, y) {
          if (x.dir !== y.dir)
            return x.dir ? -1 : 1;

          const nx = x.name.toLowerCase();
          const ny = y.name.toLowerCase();

          return nx < ny ? -1 : (nx > ny ? 1 : 0);
        });

        phone.files.rawFiles = items;
      }
    }
  }
}
