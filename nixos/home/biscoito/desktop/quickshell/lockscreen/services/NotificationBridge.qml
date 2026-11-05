import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: bridge
    visible: false
    readonly property string cacheDir: (Quickshell.env("HOME") || "/tmp") + "/.cache/quickshell"
    property var notifications: notifAdapter.notifications

    FileView {
        path: bridge.cacheDir + "/notif-bridge.json"
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter { id: notifAdapter; property var notifications: [] }
    }
    FileView {
        id: dismissFile
        path: bridge.cacheDir + "/notif-dismiss.json"
        watchChanges: false
        onAdapterUpdated: writeAdapter()
        JsonAdapter { id: dismissAdapter; property var pending: [] }
    }

    function dismiss(notificationId) {
        dismissAdapter.pending = dismissAdapter.pending.concat([notificationId])
    }
    function iconUrl(icon) {
        if (!icon || icon === "") return ""
        if (icon.startsWith("file://") || icon.startsWith("http://") || icon.startsWith("https://") || icon.startsWith("image://")) return icon
        if (icon.startsWith("/")) return "file://" + icon
        return Quickshell.iconPath(icon, "")
    }
}
