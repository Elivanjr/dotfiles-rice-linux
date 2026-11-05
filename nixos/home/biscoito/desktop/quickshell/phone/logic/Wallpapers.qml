// logic/Wallpapers.qml — Galeria de wallpapers (waypaper)
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "walls".
// Acesso de fora:  phone.walls.<membro>

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // item da view registrado por ela mesma (Binding em views/WallView.qml)
  property var wallGridRef: null

  // ================================================================
  // WALLPAPER (galeria + waypaper)
  // ================================================================

  property string wallDir:
    Quickshell.env("HOME") + "/Imagens/hyprlandWallpapers"

  property var wallpapers: []

  property int wallSelected: 0

  property string appliedWall: ""

  function baseName(path) {
    const f = (path || "").split("/").pop();
    const k = f.lastIndexOf(".");

    return k > 0 ? f.slice(0, k) : f;
  }

  function fileUrl(path) {
    return "file://" + encodeURI(path).replace(/#/g, "%23");
  }

  function refreshWalls() {
    wallProc.running = true;
  }

  function applyWall(path) {
    if (!path)
      return;

    appliedWall = path;
    Quickshell.execDetached(["waypaper", "--wallpaper", path]);
  }

  function moveWall(delta) {
    const n = wallpapers.length;

    if (n === 0)
      return;

    wallSelected = Math.max(0, Math.min(n - 1, wallSelected + delta));
  }

  function handleWallKey(e) {
    switch (e.key) {
    case Qt.Key_Escape:
    case Qt.Key_Backspace:
      phone.view = "menu";
      break;

    case Qt.Key_Left:  moveWall(-1); break;
    case Qt.Key_Right: moveWall(1);  break;
    case Qt.Key_Up:    moveWall(-3); break;
    case Qt.Key_Down:  moveWall(3);  break;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      applyWall(wallpapers[wallSelected]);
      break;

    default:
      return;
    }

    e.accepted = true;
  }

  // mantém o item selecionado visível ao navegar pelo teclado
  onWallSelectedChanged: {
    if (phone.view === "wall")
      wallGridRef?.positionViewAtIndex(wallSelected, GridView.Contain);
  }

  Process {
    id: wallProc

    running: false

    command: ["sh", "-c", `
      find "$1" -maxdepth 1 -type f \
        | grep -iE '[.](png|jpe?g|webp|bmp|gif)$' \
        | grep -vxF "$2" \
        | sort -f
    `, "sh", phone.walls.wallDir, phone.celularBg]

    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n").filter(function (l) {
          return l.length > 0;
        });

        phone.walls.wallpapers = lines;
        phone.walls.wallSelected =
          Math.max(0, Math.min(phone.walls.wallSelected, lines.length - 1));
      }
    }
  }
}
