// core/KeyDispatcher.qml — encaminha teclas ao app ativo e aplica o Esc global.

import QtQuick
import Quickshell

Scope {
  id: self

  required property var phone

  function handleKey(event) {
    const app = phone.registry.activeApp();
    const logic = app ? app.logic : null;

    if (logic && typeof logic.handleKey === "function")
      logic.handleKey(event);

    if (event.accepted)
      return;

    if (event.key === Qt.Key_Escape) {
      if (phone.view === "menu")
        phone.panelOpen = false;
      else
        phone.view = "menu";

      event.accepted = true;
    }
  }
}
