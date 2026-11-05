// Dock.qml — bottombar estilo macOS pro Quickshell/Hyprland
//
// Ícones são glifos nerd font/Font Awesome, os mesmos codepoints do
// windowRewrite do shell.qml (que por sua vez vieram da waybar) — não
// depende de tema de ícones do sistema nem de DesktopEntries.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"

PanelWindow {
  id: dock

  property var screenRef
  screen: screenRef

  // ╔══════════════════════════════════════════════════════════════════╗
  // ║  TAMANHO DA DOCK — mexe só aqui                                   ║
  // ╚══════════════════════════════════════════════════════════════════╝
  property int iconSize: 32        // tamanho de cada ícone, em px
  property int iconGap: 10         // espaço entre um ícone e outro
  property int barMargin: 8        // respiro entre os ícones e a borda do fundo (afeta a altura da barra)
  property int bottomGap: 8        // distância entre a dock e a borda de baixo da tela
  property int cornerRadius: 22    // arredondamento do fundo da dock
  // ╚══════════════════════════════════════════════════════════════════╝

  // ---------- config visual (o resto) ----------
  property string nerdFont: "JetBrainsMono NF"
  property bool dockVisible: true

  // ---------- IPC ----------
  IpcHandler {
    target: "dock"

    function toggle(): void {
      dock.dockVisible = !dock.dockVisible
    }

    function show(): void {
      dock.dockVisible = true
    }

    function hide(): void {
      dock.dockVisible = false
    }
  }

  anchors {
    bottom: true
  }

  margins {
    bottom: dock.bottomGap
  }

  exclusiveZone: 0

  implicitWidth: rowLayout.implicitWidth + barMargin * 2
  implicitHeight: iconSize + barMargin * 2

  color: "transparent"
  visible: dock.dockVisible && !dock.autoHidden

  // =====================================================================
  // ESTADO DO WORKSPACE
  // =====================================================================

  QtObject {
    id: workspaceState

    property int windows: 0
  }

  readonly property bool autoHidden: workspaceState.windows > 0

  Process {
    id: workspaceProc

    command: [
      "bash",
      "-c",
      "hyprctl activeworkspace -j"
    ]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(this.text)
          workspaceState.windows = data.windows || 0
        } catch (e) {
          // Mantém o último estado conhecido.
        }
      }
    }
  }

  Timer {
    interval: 300
    running: true
    repeat: true
    triggeredOnStart: true

    onTriggered: {
      workspaceProc.running = true
    }
  }

  // =====================================================================
  // APLICATIVOS DOCK
  //
  // icon vem dos MESMOS codepoints nerd font/Font Awesome do seu
  // windowRewrite (shell.qml) — que por sua vez veio da sua waybar.
  // Pra adicionar outro app, copia um bloco e troca class/icon/exec.
  // =====================================================================

readonly property var dockApps: [
    {
        class: "brave-origin",
        icon: "󰖟",
        exec: ["brave-origin"]
    },
    {
        class: "brave-lodlkdfmihgonocnmddehnfgiljnadcf-Default",
        icon: "\uf099",
        exec: [
            "brave-origin",
            "--profile-directory=Default",
            "--app-id=lodlkdfmihgonocnmddehnfgiljnadcf"
        ]
    },
    {
        class: "brave-agimnkijcaahngcdmfeangaknmldooml-Default",
        icon: "\uf16a",
        exec: [
            "brave-origin",
            "--profile-directory=Default",
            "--app-id=agimnkijcaahngcdmfeangaknmldooml"
        ]
    },
    {
        class: "brave-cadlkienfkclaiaibeoongdcgmdikeeg-Default",
        icon: "\uec59",
        exec: [
            "brave-origin",
            "--profile-directory=Default",
            "--app-id=cadlkienfkclaiaibeoongdcgmdikeeg"
        ]
    },
    {
        class: "codium",
        icon: "\uf372",
        exec: ["codium"]
    },
    {
        class: "discord",
        icon: "\uf1ff",
        exec: ["discord"]
    },
    {
        class: "Spotify",
        icon: "\uf1bc",
        exec: ["spotify"]
    },
    {
        class: "kitty",
        icon: "\uf489",
        exec: ["kitty"]
    }

    // ---- cola um bloco novo AQUI embaixo pra adicionar outro app ----
    // { class: "initialClass-do-app", icon: "\\uXXXX", exec: ["comando"] },
]

  // =====================================================================
  // LIXEIRA
  // =====================================================================

  readonly property var trashItem: ({
    label: "Lixeira",
    icon: "\uf1f8",
    exec: ["nautilus", "trash:///"]
  })

  // =====================================================================
  // CLIENTES DO HYPRLAND
  // =====================================================================

  QtObject {
    id: clientsState

    property var classes: []
  }

  Process {
    id: clientsProc

    command: [
      "bash",
      "-c",
      "hyprctl clients -j"
    ]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(this.text)

          clientsState.classes = data.map(
            c => c.initialClass || c.class || ""
          )
        } catch (e) {
          // Mantém o último estado conhecido.
        }
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true

    onTriggered: {
      clientsProc.running = true
    }
  }

  function isRunning(appClass) {
    const re = new RegExp("^(" + appClass + ")$")
    return clientsState.classes.some(
      cls => re.test(cls)
    )
  }

  Process {
    id: launchProc
  }

  Process {
    id: focusProc
  }

  Process {
    id: trashProc
  }

  function launchOrFocus(app) {
    if (dock.isRunning(app.class)) {
      focusProc.command = [
        "bash",
        "-c",
        "hyprctl dispatch focuswindow 'class:^(" +
        app.class +
        ")$'"
      ]

      focusProc.running = true
    } else {
      launchProc.command = app.exec
      launchProc.running = true
    }
  }

  // =====================================================================
  // ÍCONE DO DOCK
  // =====================================================================

  component DockIcon: Item {
    id: iconItem

    required property var modelData

    property bool hovered: false

    // ---------------------------------------------------------------
    // DesktopEntry REAL DO SISTEMA
    // ---------------------------------------------------------------

    readonly property bool running:
      dock.isRunning(modelData.class)

    Layout.preferredWidth:
      dock.iconSize

    Layout.preferredHeight:
      dock.iconSize

    Layout.alignment:
      Qt.AlignVCenter

    // ---------------------------------------------------------------
    // MAGNIFICAÇÃO
    // ---------------------------------------------------------------

    scale: hovered ? 1.25 : 1.0

    transformOrigin: Item.Bottom

    Behavior on scale {
      NumberAnimation {
        duration: 120
        easing.type: Easing.OutCubic
      }
    }

    // ---------------------------------------------------------------
    // FUNDO DO ÍCONE
    // ---------------------------------------------------------------

    Rectangle {
      anchors.fill: parent

      radius: 12

      color:
        Colors.md3.surface_container

      opacity:
        iconItem.hovered ? 1.0 : 0.001

      Behavior on opacity {
        NumberAnimation {
          duration: 120
        }
      }
    }

    // ---------------------------------------------------------------
    // GLIFO DO ÍCONE (nerd font / Font Awesome, mesmos da waybar)
    // ---------------------------------------------------------------

    Text {
      anchors.centerIn: parent

      text: iconItem.modelData.icon

      font.family: dock.nerdFont
      font.pixelSize: dock.iconSize * 0.5

      color: Colors.md3.on_surface
    }

    // ---------------------------------------------------------------
    // INDICADOR DE APP ABERTO
    // ---------------------------------------------------------------

    Rectangle {
      visible: iconItem.running

      width: 4
      height: 4

      radius: 2

      color:
        Colors.md3.primary

      anchors.horizontalCenter:
        parent.horizontalCenter

      anchors.bottom:
        parent.bottom

      anchors.bottomMargin: -6
    }

    // ---------------------------------------------------------------
    // CLIQUE
    // ---------------------------------------------------------------

    MouseArea {
      anchors.fill: parent

      hoverEnabled: true

      cursorShape:
        Qt.PointingHandCursor

      onEntered: {
        iconItem.hovered = true
      }

      onExited: {
        iconItem.hovered = false
      }

      onClicked: {
        dock.launchOrFocus(
          iconItem.modelData
        )
      }
    }
  }

  // =====================================================================
  // FUNDO DO DOCK
  // =====================================================================

  Rectangle {
    anchors.fill: parent

    radius: dock.cornerRadius

    color:
      Colors.md3.surface_container

    opacity: 0.85

    border.width: 1

    border.color:
      Qt.rgba(
        Colors.md3.outline.r,
        Colors.md3.outline.g,
        Colors.md3.outline.b,
        0.25
      )
  }

  // =====================================================================
  // CONTEÚDO
  // =====================================================================

  RowLayout {
    id: rowLayout

    anchors.centerIn: parent

    spacing:
      dock.iconGap

    Repeater {
      model:
        dock.dockApps

      DockIcon {}
    }

    // ---------------------------------------------------------------
    // SEPARADOR
    // ---------------------------------------------------------------

    Rectangle {
      Layout.preferredWidth:
        1

      Layout.preferredHeight:
        dock.iconSize * 0.7

      Layout.alignment:
        Qt.AlignVCenter

      color:
        Colors.md3.outline

      opacity: 0.4
    }

    // ---------------------------------------------------------------
    // LIXEIRA
    // ---------------------------------------------------------------

    Item {
      id: trashIcon

      property bool hovered: false

      Layout.preferredWidth:
        dock.iconSize

      Layout.preferredHeight:
        dock.iconSize

      Layout.alignment:
        Qt.AlignVCenter

      scale:
        hovered ? 1.25 : 1.0

      transformOrigin:
        Item.Bottom

      Behavior on scale {
        NumberAnimation {
          duration: 120
          easing.type: Easing.OutCubic
        }
      }

      Rectangle {
        anchors.fill: parent

        radius: 12

        color:
          Colors.md3.surface_container

        opacity:
          trashIcon.hovered ? 1.0 : 0.001

        Behavior on opacity {
          NumberAnimation {
            duration: 120
          }
        }
      }

      Text {
        anchors.centerIn: parent

        text:
          dock.trashItem.icon

        font.family:
          dock.nerdFont

        font.pixelSize:
          dock.iconSize * 0.5

        color:
          Colors.md3.on_surface
      }

      MouseArea {
        anchors.fill: parent

        hoverEnabled: true

        cursorShape:
          Qt.PointingHandCursor

        onEntered: {
          trashIcon.hovered = true
        }

        onExited: {
          trashIcon.hovered = false
        }

        onClicked: {
          trashProc.command =
            dock.trashItem.exec

          trashProc.running = true
        }
      }
    }
  }
}
