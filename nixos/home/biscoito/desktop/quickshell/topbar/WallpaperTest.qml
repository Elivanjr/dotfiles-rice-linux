import QtQuick
import Quickshell
import "modules/imgselector"

ShellRoot {
  id: root
  property bool open: true

  Shortcut { sequence: "Ctrl+Shift+W"; onActivated: root.open = !root.open }

  Variants {
    model: Quickshell.screens
    delegate: WallpaperPicker {
      required property var modelData
      screenRef: modelData
      panelOpen: root.open
      onCloseRequested: root.open = false
    }
  }
}
