import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import "theme" as Theme

Rectangle {
    id: root

    // Live values: theme/Colors.qml watches matugen's generated JSON file.
    readonly property color surface: Theme.Colors.md3.surface
    readonly property color container: Theme.Colors.md3.surface_container
    readonly property color containerHigh: Theme.Colors.md3.surface_container_high
    readonly property color containerHighest: Theme.Colors.md3.surface_container_highest
    readonly property color text: Theme.Colors.md3.source_color
    readonly property color muted: Theme.Colors.md3.outline
    readonly property color outline: Theme.Colors.md3.outline_variant
    readonly property color accent: Theme.Colors.md3.primary
    readonly property color accentText: Theme.Colors.md3.on_primary
    readonly property color danger: Theme.Colors.md3.error
    readonly property string uiFont: "JetBrains Mono"
    property string query: ""
    property int tileWidth: BooruApi.ikachan.thumb_size
    property bool pinned: false
    property string downloadDirectory: Quickshell.env("HOME") + "/Pictures/Booru"
    property bool showingFavorites: false
    property var selectedPost: null
    signal closeRequested()
    signal pinRequested()

    color: surface
    radius: 18
    clip: true

    function search(nextPage) {
        query = searchField.text.trim()
        BooruApi.request(query, nextPage || 1)
    }

    function closePreview() {
        selectedPost = null
    }

    function saveToDevice(post) {
        if (!post || !post.file)
            return
        const filename = (decodeURIComponent(post.file.split("/").pop().split("?")[0]) || "booru-image").replace(/[^A-Za-z0-9._-]/g, "_")
        const directory = root.downloadDirectory
        const quote = function(value) { return "'" + String(value).replace(/'/g, "'\\''") + "'" }
        Quickshell.execDetached(["bash", "-c", "mkdir -p " + quote(directory) + " && curl --fail --location --output " + quote(directory + "/" + filename) + " -- " + quote(post.file)])
        closePreview()
    }

    component Pill: Rectangle {
        property string label: ""
        property bool selected: false
        implicitHeight: 30
        implicitWidth: labelItem.implicitWidth + 22
        radius: height / 2
        color: selected ? root.accent : root.containerHigh
        border.width: selected ? 0 : 1
        border.color: root.outline

        Label {
            id: labelItem
            anchors.centerIn: parent
            text: parent.label
            color: parent.selected ? root.accentText : root.muted
            font.family: root.uiFont
            font.pixelSize: 11
        }
    }

    component FlatButton: Button {
        font.family: root.uiFont
        font.pixelSize: 11
        contentItem: Label {
            text: parent.text
            color: parent.enabled ? root.text : root.outline
            font: parent.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 10
            color: parent.down ? root.containerHighest : root.containerHigh
            border.width: 1
            border.color: root.outline
        }
    }

    ColumnLayout {
        id: viewerContent
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            color: root.container
            radius: 16

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 9
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 31
                    Layout.preferredHeight: 31
                    radius: width / 2
                    color: root.accent
                    Label { anchors.centerIn: parent; text: "✦"; color: root.accentText; font.pixelSize: 18 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "booru viewer"; color: root.text; font.family: root.uiFont; font.bold: true; font.pixelSize: 14 }
                    Label { text: "explore por tags"; color: root.muted; font.family: root.uiFont; font.pixelSize: 10 }
                }
                FlatButton { text: root.showingFavorites ? "voltar" : "favoritos " + BooruApi.favorites.length; onClicked: root.showingFavorites = !root.showingFavorites }
                FlatButton { text: root.pinned ? "fixado" : "fixar"; onClicked: root.pinRequested() }
                FlatButton { text: "×"; onClicked: root.closeRequested() }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: searchRow.implicitHeight + 12
            color: root.container
            radius: 16
            border.width: searchField.activeFocus ? 1 : 0
            border.color: root.accent

            RowLayout {
                id: searchRow
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                Label { text: "⌕"; color: root.accent; font.pixelSize: 24; leftPadding: 6 }
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: "tags: landscape blue_sky"
                    placeholderTextColor: root.muted
                    selectByMouse: true
                    color: root.text
                    font.family: root.uiFont
                    font.pixelSize: 12
                    background: Item {}
                    onAccepted: root.search(1)
                }
                Button {
                    text: "buscar"
                    font.family: root.uiFont
                    font.pixelSize: 11
                    onClicked: root.search(1)
                    contentItem: Label { text: parent.text; color: root.accentText; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: 11; color: parent.down ? Qt.darker(root.accent, 1.15) : root.accent }
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 31
            contentWidth: providerChips.implicitWidth
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: providerChips
                spacing: 6
                Repeater {
                    model: BooruApi.providerNames
                    delegate: Pill {
                        required property string modelData
                        label: BooruApi.providers[modelData].label
                        selected: BooruApi.provider === modelData
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: BooruApi.provider = modelData }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Switch {
                id: nsfwSwitch
                text: "permitir nsfw"
                checked: BooruApi.allowNsfw
                enabled: BooruApi.provider !== "alcy" && BooruApi.provider !== "safebooru"
                onToggled: BooruApi.allowNsfw = checked
                indicator: Rectangle {
                    implicitWidth: 34; implicitHeight: 18; radius: 10
                    color: nsfwSwitch.checked ? root.danger : root.containerHighest
                    border.width: 1; border.color: root.outline
                    Rectangle { width: 12; height: 12; radius: 7; anchors.verticalCenter: parent.verticalCenter; x: nsfwSwitch.checked ? 18 : 3; color: root.surface; Behavior on x { NumberAnimation { duration: 130 } } }
                }
                contentItem: Label { text: nsfwSwitch.text; leftPadding: nsfwSwitch.indicator.width + 7; color: nsfwSwitch.enabled ? root.muted : root.outline; font.family: root.uiFont; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
            }
            Item { Layout.fillWidth: true }
            BusyIndicator { running: BooruApi.busy; visible: running; implicitWidth: 22; implicitHeight: 22 }
            Label { text: root.showingFavorites ? BooruApi.favorites.length + " favoritos" : (BooruApi.busy ? "buscando…" : BooruApi.posts.length + " imagens"); color: root.muted; font.family: root.uiFont; font.pixelSize: 10 }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: BooruApi.error.length > 0
            implicitHeight: errorLabel.implicitHeight + 20
            radius: 12
            color: "#352124"
            border.width: 1
            border.color: root.danger
            Label { id: errorLabel; anchors.fill: parent; anchors.margins: 10; text: "!  " + BooruApi.error; wrapMode: Text.WordWrap; color: root.danger; font.family: root.uiFont; font.pixelSize: 11 }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ScrollView {
                anchors.fill: parent
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                GridView {
                    id: grid
                    width: parent.width
                    height: parent.height
                    cellWidth: Math.max(root.tileWidth, Math.floor(width / Math.max(1, Math.floor(width / root.tileWidth))))
                    cellHeight: cellWidth * 0.78
                    model: root.showingFavorites ? BooruApi.favorites : BooruApi.posts
                    onAtYEndChanged: {
                        if (atYEnd && !root.showingFavorites && !BooruApi.busy && BooruApi.ikachan.infinite_scroll && root.query.length > 0)
                            BooruApi.request(root.query, BooruApi.page + 1, true)
                    }
                    delegate: Item {
                        required property var modelData
                        width: grid.cellWidth
                        height: grid.cellHeight
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 13
                            color: root.container
                            clip: true
                            Image { anchors.fill: parent; source: modelData.preview; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                            Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08); radius: 13 }
                            Rectangle {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                height: 34; color: "#d812141a"
                                Label { anchors.fill: parent; anchors.margins: 7; text: modelData.tags; elide: Text.ElideRight; color: root.text; font.family: root.uiFont; font.pixelSize: 9; verticalAlignment: Text.AlignVCenter }
                            }
                            MouseArea { anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedPost = modelData }
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: !BooruApi.busy && (root.showingFavorites ? BooruApi.favorites.length : BooruApi.posts.length) === 0 && BooruApi.error.length === 0
                spacing: 8
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: "✦"; color: root.containerHighest; font.pixelSize: 47 }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.showingFavorites ? "nenhum favorito salvo" : "busque por uma tag"; color: root.muted; font.family: root.uiFont; font.pixelSize: 11 }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            FlatButton { text: "‹ anterior"; enabled: BooruApi.page > 1 && !BooruApi.busy; onClicked: root.search(BooruApi.page - 1) }
            Item { Layout.fillWidth: true }
            Pill { label: "página " + BooruApi.page }
            Item { Layout.fillWidth: true }
            FlatButton { text: "próxima ›"; enabled: !BooruApi.busy; onClicked: root.search(BooruApi.page + 1) }
        }
    }

    Item {
        id: previewOverlay
        anchors.fill: parent
        visible: root.selectedPost !== null
        z: 20

        FastBlur {
            anchors.fill: parent
            source: viewerContent
            radius: 42
            transparentBorder: true
        }
        Rectangle { anchors.fill: parent; color: "#a812141a" }
        MouseArea { anchors.fill: parent; onClicked: root.closePreview() }

        Rectangle {
            id: previewCard
            anchors.centerIn: parent
            width: Math.min(parent.width - 34, 440)
            height: Math.min(parent.height - 44, 650)
            radius: 20
            color: root.container
            border.width: 1
            border.color: root.outline
            clip: true

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Image {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    source: root.selectedPost ? root.selectedPost.file : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                Label {
                    Layout.fillWidth: true
                    text: root.selectedPost ? root.selectedPost.tags : ""
                    color: root.muted
                    font.family: root.uiFont
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.fillWidth: true
                    FlatButton { text: "favoritar"; onClicked: { BooruApi.addFavorite(root.selectedPost); root.closePreview() } }
                    Item { Layout.fillWidth: true }
                    FlatButton { text: "salvar no dispositivo"; onClicked: root.saveToDevice(root.selectedPost) }
                    FlatButton { text: "voltar"; onClicked: root.closePreview() }
                }
            }
        }
    }
}
