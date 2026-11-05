import Quickshell
import QtQuick

// Janela própria do teste. Fica separada para o shell.qml só precisar de UMA linha.
PanelWindow {
    anchors { left: true; bottom: true }
    margins { left: 24; bottom: 24 }
    implicitWidth: 240
    implicitHeight: 320
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}   // clique atravessa a janela

    MikoAvatar { anchors.fill: parent }
}
