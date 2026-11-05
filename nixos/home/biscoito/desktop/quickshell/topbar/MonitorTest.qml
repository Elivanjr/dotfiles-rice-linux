// MonitorTest.qml — teste isolado do MonitorProfile (mesmo padrão do SshTest/ToolsTest)
//
// Fica na RAIZ do topbar de propósito: assim o Quickshell enxerga a pasta
// theme/ como parte do shell e gera o qmldir do singleton Colors.
//
//   cd ~/.config/quickshell/topbar
//   qs -p MonitorTest.qml
//   qs -p MonitorTest.qml ipc call monitorprofile prompt

import Quickshell
import "modules/sharescreen" as ShareScreen

ShellRoot {
  ShareScreen.MonitorProfile {}
}
