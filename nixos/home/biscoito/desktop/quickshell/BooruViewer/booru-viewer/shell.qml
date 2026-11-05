import Quickshell

ShellRoot {
    // This is the standalone launcher. Closing the sidebar must also close this
    // Quickshell process; otherwise its invisible overlay could retain focus.
    BooruSidebar {
        // Altere apenas este caminho para escolher onde os arquivos são salvos.
        downloadDirectory: BooruApi.ikachan.save_path || (Quickshell.env("HOME") + "/Imagens/Booru")
        onCloseRequested: Qt.quit()
    }
}
