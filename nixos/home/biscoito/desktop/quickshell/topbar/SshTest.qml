import QtQuick
import Quickshell
import "modules/ai"

ShellRoot {
  id: root

  // Atalho útil no teste isolado: Ctrl+Shift+S esconde/mostra o painel sem
  // encerrar o processo do Quickshell nem a conexão SSH destacada.
  property bool sshPanelOpen: true

  Shortcut {
    sequence: "Ctrl+Shift+S"
    onActivated: root.sshPanelOpen = !root.sshPanelOpen
  }

  Variants {
    model: Quickshell.screens

    delegate: SshWidget {
      required property var modelData

      screenRef: modelData
      panelOpen: root.sshPanelOpen
      onCloseRequested: root.sshPanelOpen = false
    }
  }
}
