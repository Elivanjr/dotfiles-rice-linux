import QtQuick
import QtWebEngine

// Componente do avatar (apenas visual). Instanciado por MikoWindow.qml.
Rectangle {
    width: 240
    height: 320
    color: "transparent"
    clip: true

    WebEngineView {
        anchors.fill: parent
        backgroundColor: "transparent"
        url: "http://127.0.0.1:8765/avatar.html"
        onJavaScriptConsoleMessage: (level, message, lineNumber, sourceID) =>
            console.log("[miko-js]", message)
        onLoadingChanged: (req) =>
            console.log("[miko-load] status=" + req.status + " " + req.errorString)
    }
}
