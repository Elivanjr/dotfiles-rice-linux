// ToolsTest.qml — integra ToolRail + SSH + Chat IA + Wallpaper
// Coloca em ~/.config/quickshell/topbar/

import QtQuick
import Quickshell
import "modules/tools"
import "modules/ai"
import "modules/imgselector"

ShellRoot {
  id: root

  property string activePanel: ""
  property int railPad: 60

  function toggle(tool) {
    root.activePanel = (root.activePanel === tool) ? "" : tool
  }

  // Esc fecha o painel ativo de qualquer lugar
  Shortcut {
    sequence: "Escape"
    onActivated: root.activePanel = ""
  }

  // ── rail de navegação ────────────────────────────────────────
  Variants {
    model: Quickshell.screens
    delegate: ToolRail {
      required property var modelData
      screenRef: modelData
      active: root.activePanel
      onToggle: (tool) => root.toggle(tool)
      onRailWidthChanged: root.railPad = railWidth + 8
    }
  }

  // ── SSH ──────────────────────────────────────────────────────
  Variants {
    model: Quickshell.screens
    delegate: SshWidget {
      required property var modelData
      screenRef: modelData
      panelOpen: root.activePanel === "ssh"
      leftPad: root.railPad
      onCloseRequested: root.activePanel = ""
    }
  }

  // ── Chat IA ───────────────────────────────────────────────────
  // ANTES DE DESCOMENTAR leftPad, adicione ao AiSidebar.qml:
  //   1. após `property bool pinned: false`:
  //        property int leftPad: 0
  //   2. no x do card (linha com `8 - (1 - ai.slide) * 36`):
  //        x: ai.leftPad + 8 - (1 - ai.slide) * 36
  Variants {
    model: Quickshell.screens
    delegate: AiSidebar {
      required property var modelData
      screenRef: modelData
      panelOpen: root.activePanel === "ai"
      // leftPad: root.railPad   // descomente após adicionar leftPad no AiSidebar.qml
      onCloseRequested: root.activePanel = ""
    }
  }

  // ── Wallpaper ─────────────────────────────────────────────────
  Variants {
    model: Quickshell.screens
    delegate: WallpaperPicker {
      required property var modelData
      screenRef: modelData
      panelOpen: root.activePanel === "wall"
      leftPad: root.railPad
      onCloseRequested: root.activePanel = ""
    }
  }
}
