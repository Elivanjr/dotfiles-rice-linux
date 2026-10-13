// Colors.qml — paleta gerada pelo matugen (Material You a partir do wallpaper)
//
// Baseado no template oficial de Quickshell do InioX/matugen-themes:
// https://github.com/InioX/matugen-themes (seção "Quickshell")
//
// Como funciona:
//   1. O matugen roda (manual ou num post_hook do seu trocador de wallpaper)
//      e escreve ~/.local/state/quickshell/generated/colors.json
//   2. Esse singleton observa esse arquivo (FileView + watchChanges) e
//      recarrega sozinho sempre que ele muda — sem precisar reiniciar o
//      quickshell.
//   3. Se o arquivo ainda não existir (matugen nunca rodou), os valores
//      default abaixo são usados, então a barra não quebra visualmente.
//
// Uso no shell.qml: Colors.md3.primary, Colors.md3.on_surface, etc.
// (string com hex — atribui direto numa property do tipo "color", que
// converte sozinha)
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
	property alias md3: jsonAdapter.md3

	FileView {
		path: Quickshell.env("HOME") + "/.local/state/quickshell/generated/colors.json"
		watchChanges: true
		onFileChanged: reload()

		JsonAdapter {
			id: jsonAdapter
			readonly property Md3 md3: Md3 {}
		}
	}

	// papéis do Material 3 que a topbar usa — surface_container/source_color
	// espelham o que o style.css da waybar do usuário usa (@color15/@source_color)
	// pra fundo e texto dos módulos; outline/primary seguem os mesmos que já
	// estavam (texto apagado / cor de destaque).
	component Md3: JsonObject {
		property string surface: "#12141a"
		property string surface_container: "#1c1e26"
		property string on_surface: "#f2f0ea"
		property string source_color: "#f2f0ea"
		property string outline: "#9aa08f"
		property string primary: "#8fbf6b"
	}
}
