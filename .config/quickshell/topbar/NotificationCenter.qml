// NotificationCenter.qml — central de notificações
//
// Layout inspirado no notification center do GNOME:
//   - notificações à esquerda
//   - calendário à direita
//   - Spotify no painel direito
//   - DND embaixo à esquerda
//   - Apagar embaixo à direita
//
// A abertura/fechamento continua sendo controlada externamente por
// panelOpen / closeRequested(), como no shell.qml.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris

PanelWindow {
  id: notifCenter

  required property var screenRef
  screen: screenRef

  property bool panelOpen: false

  visible: panelOpen

  color: "transparent"
  focusable: true

  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  signal closeRequested()

  // ================================================================
  // CORES — MATUGEN
  // ================================================================

  readonly property color colSurface:
    Colors.md3.surface

  readonly property color colModBg:
    Colors.md3.surface_container

  readonly property color colText:
    Colors.md3.source_color

  readonly property color colMuted:
    Colors.md3.outline

  readonly property color colAccent:
    Colors.md3.primary

  // ================================================================
  // SPOTIFY
  // ================================================================

  readonly property var spotifyPlayer: {
    for (const p of Mpris.players.values) {
      if (
        (p.identity || "")
          .toLowerCase()
          .indexOf("spotify") !== -1
      ) {
        return p;
      }
    }

    return null;
  }

  readonly property var mediaPlayer:
    spotifyPlayer

  // ================================================================
  // ÍCONES DAS NOTIFICAÇÕES
  // ================================================================

  function resolveIcon(icon) {
    if (!icon || icon === "")
      return "";

    if (
      icon.startsWith("file://") ||
      icon.startsWith("http://") ||
      icon.startsWith("https://") ||
      icon.startsWith("image://")
    ) {
      return icon;
    }

    if (icon.startsWith("/"))
      return "file://" + icon;

    return Quickshell.iconPath(icon, "");
  }

  // ================================================================
  // CALENDÁRIO
  // ================================================================

  readonly property var monthNames: [
    "janeiro",
    "fevereiro",
    "março",
    "abril",
    "maio",
    "junho",
    "julho",
    "agosto",
    "setembro",
    "outubro",
    "novembro",
    "dezembro"
  ]

  readonly property var weekDays: [
    "D",
    "S",
    "T",
    "Q",
    "Q",
    "S",
    "S"
  ]

  property int calendarMonth:
    new Date().getMonth()

  property int calendarYear:
    new Date().getFullYear()

  function daysInMonth(year, month) {
    return new Date(year, month + 1, 0).getDate();
  }

  function firstDayOfMonth(year, month) {
    return new Date(year, month, 1).getDay();
  }

  function previousMonth() {
    if (calendarMonth === 0) {
      calendarMonth = 11;
      calendarYear--;
    } else {
      calendarMonth--;
    }
  }

  function nextMonth() {
    if (calendarMonth === 11) {
      calendarMonth = 0;
      calendarYear++;
    } else {
      calendarMonth++;
    }
  }

  function isToday(day) {
    const now = new Date();

    return (
      day === now.getDate() &&
      calendarMonth === now.getMonth() &&
      calendarYear === now.getFullYear()
    );
  }

  // ================================================================
  // JANELA
  // ================================================================

  anchors {
    top: true
    left: true
  }

  implicitWidth: 700
  implicitHeight: 500

  margins.top: 6

  margins.left:
    Math.round(
      (screenRef.width - implicitWidth) / 2
    )

  onPanelOpenChanged: {
  if (!panelOpen)
    return;

  card.forceActiveFocus();

  calendarMonth =
    new Date().getMonth();

  calendarYear =
    new Date().getFullYear();
}

  // ================================================================
  // CARD PRINCIPAL
  // ================================================================

  Rectangle {
    id: card

    anchors.fill: parent

    radius: 16

    color: notifCenter.colSurface

    border.color:
      Qt.rgba(
        notifCenter.colText.r,
        notifCenter.colText.g,
        notifCenter.colText.b,
        0.06
      )

    border.width: 1

    focus: true

    Keys.onEscapePressed:
      notifCenter.closeRequested()

    RowLayout {
      anchors.fill: parent

      anchors.margins: 10

      spacing: 8

      // ============================================================
      // LADO ESQUERDO — NOTIFICAÇÕES
      // ============================================================

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Layout.minimumWidth: 400

        spacing: 8

        // ----------------------------------------------------------
        // LISTA
        // ----------------------------------------------------------

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true

          radius: 12

          color: "transparent"

          ListView {
            id: notificationList

            anchors.fill: parent

            clip: true

            spacing: 6

            model:
              NotificationService.notifHistory

            delegate: Rectangle {
              required property var modelData

              width:
                notificationList.width

              implicitHeight:
                notificationColumn.implicitHeight + 16

              radius: 10

              color:
                Qt.rgba(
                  notifCenter.colText.r,
                  notifCenter.colText.g,
                  notifCenter.colText.b,
                  0.045
                )

              RowLayout {
                anchors.fill: parent

                anchors.margins: 8

                spacing: 8

                // ------------------------------------------------
                // ÍCONE
                // ------------------------------------------------

                Rectangle {
                  visible:
                    notifCenter.resolveIcon(
                      modelData.image
                    ) !== "" ||
                    notifCenter.resolveIcon(
                      modelData.appIcon
                    ) !== ""

                  Layout.preferredWidth: 34
                  Layout.preferredHeight: 34

                  radius: 7

                  color:
                    Qt.rgba(
                      0,
                      0,
                      0,
                      0.20
                    )

                  clip: true

                  Image {
                    anchors.fill: parent

                    source:
                      notifCenter.resolveIcon(
                        modelData.image
                      ) ||
                      notifCenter.resolveIcon(
                        modelData.appIcon
                      )

                    fillMode:
                      Image.PreserveAspectCrop

                    asynchronous: true
                  }
                }

                // ------------------------------------------------
                // CONTEÚDO
                // ------------------------------------------------

                ColumnLayout {
                  id: notificationColumn

                  Layout.fillWidth: true

                  spacing: 2

                  RowLayout {
                    Layout.fillWidth: true

                    Text {
                      text:
                        modelData.appName

                      color:
                        notifCenter.colAccent

                      font.family:
                        "JetBrainsMono NF"

                      font.pixelSize: 10

                      Layout.fillWidth: true
                    }

                    Text {
                      text:
                        modelData.time

                      color:
                        notifCenter.colMuted

                      font.family:
                        "JetBrainsMono NF"

                      font.pixelSize: 9
                    }
                  }

                  Text {
                    text:
                      modelData.summary

                    color:
                      notifCenter.colText

                    font.family:
                      "JetBrainsMono NF"

                    font.bold: true

                    font.pixelSize: 11

                    wrapMode:
                      Text.WordWrap

                    Layout.fillWidth: true
                  }

                  Text {
                    visible:
                      modelData.body !== ""

                    text:
                      modelData.body

                    color:
                      notifCenter.colMuted

                    font.family:
                      "JetBrainsMono NF"

                    font.pixelSize: 10

                    wrapMode:
                      Text.WordWrap

                    Layout.fillWidth: true

                    maximumLineCount: 3

                    elide:
                      Text.ElideRight
                  }
                }
              }
            }
          }

          // ------------------------------------------------------
          // ESTADO VAZIO
          // ------------------------------------------------------

          Column {
            anchors.centerIn: parent

            spacing: 8

            visible:
              NotificationService.notifHistory.length === 0

            Text {
              anchors.horizontalCenter: parent.horizontalCenter

              text: "\u{F0F3}"

              color:
                notifCenter.colText

              font.family:
                "Font Awesome 6 Free"

              font.pixelSize: 24
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter

              text: "No Notifications"

              color:
                notifCenter.colMuted

              font.family:
                "JetBrainsMono NF"

              font.pixelSize: 11
            }
          }
        }

        // ----------------------------------------------------------
        // BARRA INFERIOR
        // ----------------------------------------------------------

        RowLayout {
          Layout.fillWidth: true

          spacing: 8

          // ========================================================
          // NÃO PERTURBE — ESQUERDA
          // ========================================================

          RowLayout {
            spacing: 7

            Text {
              text:
                "\u{F1F6}"

              color:
                notifCenter.colMuted

              font.pixelSize: 12
            }

            Text {
              text:
                "Não perturbe"

              color:
                notifCenter.colMuted

              font.family:
                "JetBrainsMono NF"

              font.pixelSize: 10
            }

            Rectangle {
              Layout.preferredWidth: 34
              Layout.preferredHeight: 18

              radius: 9

              color:
                NotificationService.dndEnabled
                  ? notifCenter.colAccent
                  : Qt.rgba(
                      1,
                      1,
                      1,
                      0.10
                    )

              Rectangle {
                width: 14
                height: 14

                radius: 7

                anchors.verticalCenter:
                  parent.verticalCenter

                x:
                  NotificationService.dndEnabled
                    ? parent.width - width - 2
                    : 2

                color:
                  notifCenter.colText

                Behavior on x {
                  NumberAnimation {
                    duration: 140
                  }
                }
              }

              MouseArea {
                anchors.fill: parent

                onClicked:
                  NotificationService.dndEnabled =
                    !NotificationService.dndEnabled
              }
            }
          }

          // Empurra o botão Apagar para o lado direito.
          Item {
            Layout.fillWidth: true
          }

          // ========================================================
          // APAGAR — DIREITA
          // ========================================================

          Rectangle {
            implicitWidth:
              clearText.implicitWidth + 18

            implicitHeight: 26

            radius: 8

            color:
              Qt.rgba(
                notifCenter.colText.r,
                notifCenter.colText.g,
                notifCenter.colText.b,
                0.06
              )

            Text {
              id: clearText

              anchors.centerIn: parent

              text:
                "Apagar"

              color:
                notifCenter.colAccent

              font.family:
                "JetBrainsMono NF"

              font.pixelSize: 10
            }

            MouseArea {
              anchors.fill: parent

              cursorShape:
                Qt.PointingHandCursor

              onClicked:
                NotificationService.clearNotifHistory()
            }
          }
        }
      }

      // ============================================================
      // SEPARADOR
      // ============================================================

      Rectangle {
        Layout.fillHeight: true

        Layout.preferredWidth: 1

        color:
          Qt.rgba(
            notifCenter.colText.r,
            notifCenter.colText.g,
            notifCenter.colText.b,
            0.07
          )
      }

      // ============================================================
      // LADO DIREITO
      // ============================================================

      ColumnLayout {
        Layout.preferredWidth: 240
        Layout.fillHeight: true

        spacing: 8

        // ----------------------------------------------------------
        // DATA
        // ----------------------------------------------------------

        ColumnLayout {
          Layout.fillWidth: true

          spacing: 1

          Text {
            text: {
              const d = new Date(
                calendarYear,
                calendarMonth,
                1
              );

              const weekdays = [
                "domingo",
                "segunda",
                "terça",
                "quarta",
                "quinta",
                "sexta",
                "sábado"
              ];

              return weekdays[d.getDay()];
            }

            color:
              notifCenter.colMuted

            font.family:
              "JetBrainsMono NF"

            font.pixelSize: 10
          }

          Text {
            text:
              monthNames[calendarMonth] +
              " " +
              calendarYear

            color:
              notifCenter.colText

            font.family:
              "JetBrainsMono NF"

            font.bold: true

            font.pixelSize: 18
          }
        }

        // ----------------------------------------------------------
        // CALENDÁRIO
        // ----------------------------------------------------------

        Rectangle {
          Layout.fillWidth: true

          Layout.preferredHeight: 194

          radius: 10

          color:
            Qt.rgba(
              notifCenter.colText.r,
              notifCenter.colText.g,
              notifCenter.colText.b,
              0.035
            )

          border.color:
            Qt.rgba(
              notifCenter.colText.r,
              notifCenter.colText.g,
              notifCenter.colText.b,
              0.06
            )

          border.width: 1

          ColumnLayout {
            anchors.fill: parent

            anchors.margins: 8

            spacing: 5

            RowLayout {
              Layout.fillWidth: true

              Text {
                text: "\u{F053}"

                color:
                  notifCenter.colText

                font.pixelSize: 10

                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -5

                  onClicked:
                    notifCenter.previousMonth()
                }
              }

              Text {
                text:
                  monthNames[
                    calendarMonth
                  ]

                color:
                  notifCenter.colText

                font.family:
                  "JetBrainsMono NF"

                font.bold: true

                font.pixelSize: 10

                horizontalAlignment:
                  Text.AlignHCenter

                Layout.fillWidth: true
              }

              Text {
                text: "\u{F054}"

                color:
                  notifCenter.colText

                font.pixelSize: 10

                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -5

                  onClicked:
                    notifCenter.nextMonth()
                }
              }
            }

            GridLayout {
              columns: 7

              Layout.fillWidth: true

              Repeater {
                model:
                  notifCenter.weekDays

                Text {
                  required property string modelData

                  text:
                    modelData

                  color:
                    notifCenter.colMuted

                  font.family:
                    "JetBrainsMono NF"

                  font.pixelSize: 8

                  horizontalAlignment:
                    Text.AlignHCenter

                  Layout.fillWidth: true
                }
              }
            }

            GridLayout {
              columns: 7

              Layout.fillWidth: true
              Layout.fillHeight: true

              Repeater {
                model: 42

                Item {
                  required property int index

                  Layout.fillWidth: true
                  Layout.fillHeight: true

                  readonly property int day:
                    index -
                    notifCenter.firstDayOfMonth(
                      notifCenter.calendarYear,
                      notifCenter.calendarMonth
                    ) +
                    1

                  readonly property int totalDays:
                    notifCenter.daysInMonth(
                      notifCenter.calendarYear,
                      notifCenter.calendarMonth
                    )

                  readonly property bool validDay:
                    day >= 1 &&
                    day <= totalDays

                  Rectangle {
                    anchors.centerIn: parent

                    width: 22
                    height: 22

                    radius: 11

                    visible:
                      parent.validDay &&
                      notifCenter.isToday(
                        parent.day
                      )

                    color:
                      notifCenter.colAccent

                    Text {
                      anchors.centerIn: parent

                      text:
                        parent.parent.day

                      color:
                        notifCenter.colSurface

                      font.family:
                        "JetBrainsMono NF"

                      font.bold: true

                      font.pixelSize: 8
                    }
                  }

                  Text {
                    anchors.centerIn: parent

                    visible:
                      parent.validDay &&
                      !notifCenter.isToday(
                        parent.day
                      )

                    text:
                      parent.day

                    color:
                      notifCenter.colText

                    font.family:
                      "JetBrainsMono NF"

                    font.pixelSize: 8
                  }
                }
              }
            }
          }
        }

        // ----------------------------------------------------------
        // TODAY
        // ----------------------------------------------------------

        Rectangle {
          Layout.fillWidth: true

          Layout.preferredHeight: 48

          radius: 8

          color:
            Qt.rgba(
              notifCenter.colText.r,
              notifCenter.colText.g,
              notifCenter.colText.b,
              0.035
            )

          border.color:
            Qt.rgba(
              notifCenter.colText.r,
              notifCenter.colText.g,
              notifCenter.colText.b,
              0.06
            )

          border.width: 1

          ColumnLayout {
            anchors.fill: parent

            anchors.margins: 8

            spacing: 2

            Text {
              text: "Today"

              color:
                notifCenter.colText

              font.family:
                "JetBrainsMono NF"

              font.pixelSize: 10
            }

            Text {
              text: "No Events"

              color:
                notifCenter.colMuted

              font.family:
                "JetBrainsMono NF"

              font.pixelSize: 9
            }
          }
        }

        // ----------------------------------------------------------
        // WORLD CLOCKS
        // ----------------------------------------------------------

        Rectangle {
          Layout.fillWidth: true

          Layout.preferredHeight: 34

          radius: 8

          color:
            Qt.rgba(
              notifCenter.colText.r,
              notifCenter.colText.g,
              notifCenter.colText.b,
              0.035
            )

          border.color:
            Qt.rgba(
              notifCenter.colText.r,
              notifCenter.colText.g,
              notifCenter.colText.b,
              0.06
            )

          border.width: 1

          Text {
            anchors.fill: parent

            anchors.margins: 8

            text:
              "Add world clocks..."

            color:
              notifCenter.colMuted

            font.family:
              "JetBrainsMono NF"

            font.pixelSize: 9

            verticalAlignment:
              Text.AlignVCenter
          }
        }

        // ----------------------------------------------------------
        // SPOTIFY
        // ----------------------------------------------------------

        Rectangle {
          visible:
            notifCenter.mediaPlayer !== null

          Layout.fillWidth: true

          Layout.preferredHeight: 92

          radius: 8

          color:
            Qt.rgba(
              notifCenter.colText.r,
              notifCenter.colText.g,
              notifCenter.colText.b,
              0.035
            )

          border.color:
            Qt.rgba(
              notifCenter.colAccent.r,
              notifCenter.colAccent.g,
              notifCenter.colAccent.b,
              0.18
            )

          border.width: 1

          clip: true

          RowLayout {
            anchors.fill: parent

            anchors.margins: 8

            spacing: 8

            Rectangle {
              Layout.preferredWidth: 54
              Layout.preferredHeight: 54

              radius: 6

              color:
                Qt.rgba(
                  0,
                  0,
                  0,
                  0.25
                )

              clip: true

              Image {
                anchors.fill: parent

                source:
                  notifCenter.mediaPlayer
                    ? (
                        notifCenter.mediaPlayer.trackArtUrl ||
                        ""
                      )
                    : ""

                fillMode:
                  Image.PreserveAspectCrop

                asynchronous: true
              }
            }

            ColumnLayout {
              Layout.fillWidth: true

              spacing: 2

              Text {
                text:
                  notifCenter.mediaPlayer
                    ? (
                        notifCenter.mediaPlayer.trackTitle ||
                        ""
                      )
                    : ""

                color:
                  notifCenter.colText

                font.family:
                  "JetBrainsMono NF"

                font.bold: true

                font.pixelSize: 10

                elide:
                  Text.ElideRight

                Layout.fillWidth: true
              }

              Text {
                text:
                  notifCenter.mediaPlayer
                    ? (
                        notifCenter.mediaPlayer.trackArtist ||
                        ""
                      )
                    : ""

                color:
                  notifCenter.colMuted

                font.family:
                  "JetBrainsMono NF"

                font.pixelSize: 9

                elide:
                  Text.ElideRight

                Layout.fillWidth: true
              }

              Item {
                Layout.fillHeight: true
              }

              RowLayout {
                Layout.fillWidth: true

                spacing: 10

                Text {
                  text: "\u{F048}"

                  color:
                    notifCenter.colText

                  font.pixelSize: 10

                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5

                    onClicked:
                      if (notifCenter.mediaPlayer)
                        notifCenter.mediaPlayer.previous()
                  }
                }

                Text {
                  text:
                    (
                      notifCenter.mediaPlayer &&
                      notifCenter.mediaPlayer.isPlaying
                    )
                      ? "\u{F04C}"
                      : "\u{F04B}"

                  color:
                    notifCenter.colAccent

                  font.pixelSize: 10

                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5

                    onClicked:
                      if (notifCenter.mediaPlayer) {
                        notifCenter.mediaPlayer.isPlaying =
                          !notifCenter.mediaPlayer.isPlaying
                      }
                  }
                }

                Text {
                  text: "\u{F051}"

                  color:
                    notifCenter.colText

                  font.pixelSize: 10

                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5

                    onClicked:
                      if (notifCenter.mediaPlayer)
                        notifCenter.mediaPlayer.next()
                  }
                }
              }
            }
          }
        }

        Item {
          Layout.fillHeight: true
        }
      }
    }
  }
}
