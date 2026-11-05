import QtQuick
import Quickshell
import Quickshell.Wayland
import "theme" as Theme

PanelWindow {
    id: sidebar

    // The same public contract used by the topbar's AiSidebar.qml.
    // A parent shell can bind panelOpen and closeRequested to its own state.
    property bool panelOpen: true
    property bool pinned: false
    property int panelWidth: 500
    property string downloadDirectory: Quickshell.env("HOME") + "/Pictures/Booru"
    property int topInset: 8
    property int bottomInset: 8
    property real slide: 1
    signal closeRequested()

    visible: panelOpen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: !sidebar.pinned
    }

    implicitWidth: sidebar.pinned ? sidebar.panelWidth + 16 : 0
    mask: sidebar.pinned ? pinRegion : null
    WlrLayershell.layer: sidebar.pinned ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: !sidebar.panelOpen
        ? WlrKeyboardFocus.None
        : (sidebar.pinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
    WlrLayershell.namespace: "quickshell:booru-viewer"

    Region {
        id: pinRegion
        item: card
    }

    NumberAnimation {
        id: slideAnimation
        target: sidebar
        property: "slide"
        from: 0
        to: 1
        duration: 190
        easing.type: Easing.OutCubic
    }

    onPanelOpenChanged: {
        if (panelOpen)
            slideAnimation.restart()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: sidebar.closeRequested()

        // In overlay mode the transparent area becomes the dismiss target.
        MouseArea {
            anchors.fill: parent
            enabled: !sidebar.pinned
            onClicked: sidebar.closeRequested()
        }

        Rectangle {
            id: card
            width: sidebar.panelWidth
            height: parent.height - sidebar.topInset - sidebar.bottomInset
            x: 8 - (1 - sidebar.slide) * 36
            y: sidebar.topInset
            opacity: sidebar.slide
            radius: 20
            color: Theme.Colors.md3.surface
            border.width: 1
            border.color: Theme.Colors.md3.outline_variant
            clip: true

            // Consume pointer events that land in the sidebar itself.
            MouseArea { anchors.fill: parent }

            BooruViewer {
                anchors.fill: parent
                pinned: sidebar.pinned
                downloadDirectory: sidebar.downloadDirectory
                onPinRequested: sidebar.pinned = !sidebar.pinned
                onCloseRequested: sidebar.closeRequested()
            }
        }
    }
}
