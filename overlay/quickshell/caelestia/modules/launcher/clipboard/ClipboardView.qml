pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.utils
import "../studio"

// Historique du presse-papiers : liste groupée par jour à gauche, aperçu riche à droite.
Item {
    id: root

    required property var screenState
    required property var panels
    required property string query
    required property real maxHeight

    readonly property bool active: screenState.launcher
    property string filter: "all"
    property bool confirmClear

    readonly property var filters: [
        {
            key: "all",
            name: "Tout",
            icon: "content_paste"
        },
        {
            key: "text",
            name: "Texte",
            icon: "notes"
        },
        {
            key: "link",
            name: "Liens",
            icon: "link"
        },
        {
            key: "image",
            name: "Images",
            icon: "image"
        },
        {
            key: "pinned",
            name: "Épinglés",
            icon: "keep"
        }
    ]

    readonly property var kindIcons: ({
            text: "notes",
            code: "code",
            link: "link",
            colour: "palette",
            file: "description",
            image: "image",
            binary: "draft"
        })

    readonly property var all: {
        const pins = Clipboard.pins.map(p => Object.assign({
                pinned: true,
                preview: p.kind === "image" ? `[[ image ${p.width}x${p.height} ]]` : Clipboard.previewOf(p.text)
            }, p));
        return [...pins, ...Clipboard.entries.filter(e => !e.pinned)];
    }

    readonly property var counts: {
        const c = {
            all: 0,
            text: 0,
            link: 0,
            image: 0,
            pinned: 0
        };
        for (const e of searched) {
            c.all++;
            const k = matchKind(e);
            if (k)
                c[k]++;
            if (e.pinKey)
                c.pinned++;
        }
        return c;
    }

    readonly property var searched: {
        const words = query.toLowerCase().split(/\s+/).filter(w => w);
        if (!words.length)
            return all;
        Clipboard.meta;
        return all.filter(e => {
            const hay = `${e.preview} ${Clipboard.appOf(e)} ${e.kind === "image" ? "image capture" : ""}`.toLowerCase();
            return words.every(w => hay.includes(w));
        });
    }

    readonly property var visibleEntries: {
        Clipboard.meta;
        const list = searched.filter(e => filter === "all" || (filter === "pinned" ? !!e.pinKey : matchKind(e) === filter));
        let previous = "";
        return list.map(e => {
            const g = Clipboard.group(e);
            const item = Object.assign({}, e, {
                key: e.pinKey ? `pin:${e.pinKey}` : `id:${e.id}`,
                group: g,
                showHeader: g !== previous
            });
            previous = g;
            return item;
        });
    }

    readonly property var current: list.currentIndex >= 0 ? visibleEntries[list.currentIndex] ?? null : null

    readonly property real availableWidth: {
        const screen = (QsWindow.window as QsWindow)?.screen;
        if (!screen)
            return 1000;
        const barMargins = Math.max(Config.border.thickness, panels.bar.implicitWidth);
        return screen.width - Config.border.rounding * 4 - barMargins * 2 - Tokens.padding.large * 2;
    }

    function matchKind(e: var): string {
        if (e.kind === "image")
            return "image";
        if (e.kind === "link")
            return "link";
        if (e.kind === "binary")
            return "";
        return "text";
    }

    function cycleFilter(step: int): void {
        const keys = filters.map(f => f.key);
        filter = keys[(keys.indexOf(filter) + step + keys.length) % keys.length];
    }

    function activate(copyOnly: bool): void {
        const entry = current;
        if (!entry)
            return;
        screenState.launcher = false;
        Clipboard.paste(entry, copyOnly);
    }

    function handleKey(event: KeyEvent): bool {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;

        if (ctrl) {
            switch (event.key) {
            case Qt.Key_P:
                Clipboard.togglePin(current);
                return true;
            case Qt.Key_S:
                Clipboard.setPaused(!Clipboard.paused);
                return true;
            }
            return false;
        }

        switch (event.key) {
        case Qt.Key_Up:
            list.decrementCurrentIndex();
            return true;
        case Qt.Key_Down:
            list.incrementCurrentIndex();
            return true;
        case Qt.Key_PageUp:
            list.currentIndex = Math.max(0, list.currentIndex - 6);
            return true;
        case Qt.Key_PageDown:
            list.currentIndex = Math.min(list.count - 1, list.currentIndex + 6);
            return true;
        case Qt.Key_Tab:
            cycleFilter(shift ? -1 : 1);
            return true;
        case Qt.Key_Backtab:
            cycleFilter(-1);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activate(shift);
            return true;
        case Qt.Key_Delete:
            if (shift || !query) {
                const index = list.currentIndex;
                Clipboard.remove(current);
                list.currentIndex = Math.min(index, list.count - 1);
                return true;
            }
            return false;
        }
        return false;
    }

    implicitWidth: Math.min(availableWidth, 1120)
    implicitHeight: Math.min(maxHeight, 560)

    onActiveChanged: {
        if (active)
            Clipboard.acquire();
        else
            Clipboard.release();
    }
    Component.onCompleted: {
        if (active)
            Clipboard.acquire();
    }
    Component.onDestruction: {
        if (active)
            Clipboard.release();
    }

    onCurrentChanged: Clipboard.needText(current)
    onQueryChanged: list.currentIndex = 0
    onFilterChanged: list.currentIndex = 0

    Timer {
        id: clearTimer

        interval: 3000
        onTriggered: root.confirmClear = false
    }

    // ---- En-tête ----

    RowLayout {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.small

        Repeater {
            model: root.filters

            StudioChip {
                required property var modelData

                icon: modelData.icon
                text: modelData.name
                trailing: String(root.counts[modelData.key] ?? 0)
                checked: root.filter === modelData.key
                onClicked: root.filter = modelData.key
            }
        }

        Item {
            Layout.fillWidth: true
        }

        StudioChip {
            icon: Clipboard.paused ? "play_arrow" : "pause"
            text: Clipboard.paused ? "Historique en pause" : "Mettre en pause"
            checked: Clipboard.paused
            onClicked: Clipboard.setPaused(!Clipboard.paused)
        }

        StudioChip {
            icon: "delete_sweep"
            text: root.confirmClear ? "Confirmer ?" : "Vider"
            checked: root.confirmClear
            onClicked: {
                if (root.confirmClear) {
                    root.confirmClear = false;
                    Clipboard.clear();
                } else {
                    root.confirmClear = true;
                    clearTimer.restart();
                }
            }
        }
    }

    // ---- Liste ----

    StyledListView {
        id: list

        anchors.top: header.bottom
        anchors.topMargin: Tokens.spacing.medium
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: Math.round(parent.width * 0.42)

        clip: true
        spacing: Tokens.spacing.extraSmall
        keyNavigationWraps: false

        model: ScriptModel {
            values: root.visibleEntries
            objectProp: "key"
        }

        delegate: ClipItem {
            width: list.width
            onClicked: list.currentIndex = index
            onDoubleClicked: {
                list.currentIndex = index;
                root.activate(false);
            }
        }

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: list
        }
    }

    // Liste vide
    Column {
        anchors.centerIn: list
        spacing: Tokens.spacing.small
        opacity: list.count === 0 && Clipboard.loaded ? 1 : 0
        visible: opacity > 0

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.filter === "pinned" ? "keep" : "content_paste_off"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.extraLarge
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.query ? "Rien ne correspond" : (root.filter === "pinned" ? "Aucun élément épinglé" : "Historique vide")
            font: Tokens.font.title.small
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.filter === "pinned" ? "Ctrl+P épingle l'élément sélectionné" : "Ce que tu copies apparaîtra ici"
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    // ---- Aperçu ----

    StyledRect {
        id: previewPane

        anchors.top: list.top
        anchors.bottom: parent.bottom
        anchors.left: list.right
        anchors.right: parent.right
        anchors.leftMargin: Tokens.spacing.medium
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer
        opacity: root.current ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            // Contenu
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Texte, code, chemin
                StyledFlickable {
                    id: textFlick

                    anchors.fill: parent
                    visible: ["text", "code", "file", "binary"].includes(root.current?.kind ?? "")
                    clip: true
                    contentHeight: textView.implicitHeight
                    flickableDirection: Flickable.VerticalFlick

                    TextEdit {
                        id: textView

                        width: textFlick.width
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        color: Colours.palette.m3onSurface
                        selectionColor: Colours.palette.m3primaryContainer
                        selectedTextColor: Colours.palette.m3onPrimaryContainer
                        font: root.current?.kind === "code" || root.current?.kind === "file" ? Tokens.font.mono.medium : Tokens.font.body.large
                        text: {
                            const e = root.current;
                            if (!e)
                                return "";
                            if (e.kind === "binary")
                                return "Données binaires (aperçu indisponible)";
                            const full = Clipboard.fullText(e);
                            return full || e.preview;
                        }
                    }

                    StyledScrollBar.vertical: StyledScrollBar {
                        flickable: textFlick
                    }
                }

                // Image
                Image {
                    anchors.fill: parent
                    visible: root.current?.kind === "image"
                    source: visible ? WallStudio.fileUrl(Clipboard.imageFor(root.current)) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize: Qt.size(Math.round(width * 1.5), Math.round(height * 1.5))
                    smooth: true
                }

                // Lien
                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width
                    visible: root.current?.kind === "link"
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "language"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.6).build()
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            const m = (root.current?.preview ?? "").match(/^\w+:\/\/([^/?#]+)/);
                            return m ? m[1].replace(/^www\./, "") : "";
                        }
                        font: Tokens.font.title.large
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.current?.preview ?? ""
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.medium
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }

                    TextButton {
                        Layout.alignment: Qt.AlignHCenter
                        type: TextButton.Tonal
                        text: "Ouvrir dans le navigateur"
                        onClicked: {
                            Qt.openUrlExternally(root.current.preview.trim());
                            root.screenState.launcher = false;
                        }
                    }
                }

                // Couleur
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.current?.kind === "colour"
                    spacing: Tokens.spacing.medium

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 160
                        implicitHeight: 160
                        radius: Tokens.rounding.extraLarge
                        color: root.current?.kind === "colour" ? root.current.preview.trim() : "transparent"
                        border.width: 1
                        border.color: Colours.palette.m3outlineVariant
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: (root.current?.preview ?? "").trim()
                        font: Tokens.font.title.large
                    }
                }
            }

            // Pied : infos + actions
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                IconImage {
                    readonly property string app: Clipboard.appOf(root.current)

                    visible: app !== ""
                    implicitSize: 20
                    asynchronous: true
                    source: app ? Icons.getAppIcon(app, "image-missing") : ""
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const e = root.current;
                        if (!e)
                            return "";
                        const parts = [];
                        if (e.kind === "image")
                            parts.push(`${e.width}×${e.height}`, (e.format ?? "").toUpperCase(), e.size ?? "");
                        else if (e.kind !== "binary") {
                            const full = Clipboard.fullText(e) || e.preview;
                            const lines = full.split("\n").length;
                            parts.push(`${full.length} caractère${full.length > 1 ? "s" : ""}`);
                            if (lines > 1)
                                parts.push(`${lines} lignes`);
                        }
                        const time = Clipboard.relativeTime(Clipboard.timeOf(e));
                        if (time)
                            parts.push(time);
                        return parts.filter(p => p).join("  ·  ");
                    }
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                IconButton {
                    type: IconButton.Text
                    icon: "keep"
                    isToggle: true
                    checked: !!root.current?.pinKey
                    onClicked: Clipboard.togglePin(root.current)
                }

                IconButton {
                    type: IconButton.Text
                    icon: "delete"
                    onClicked: Clipboard.remove(root.current)
                }

                TextButton {
                    type: TextButton.Tonal
                    text: "Copier"
                    onClicked: root.activate(true)
                }

                IconTextButton {
                    type: TextButton.Filled
                    icon: "content_paste_go"
                    text: "Coller"
                    onClicked: root.activate(false)
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: "⏎ coller   ⇧⏎ copier   ⇥ filtre   Ctrl+P épingler   Suppr retirer   Ctrl+S pause"
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }
    }

    component ClipItem: Item {
        id: item

        required property var modelData
        required property int index
        readonly property real headerHeight: modelData.showHeader ? sectionLabel.implicitHeight + Tokens.spacing.small * 2 : 0
        readonly property bool selected: ListView.isCurrentItem

        signal clicked
        signal doubleClicked

        implicitHeight: headerHeight + 56

        StyledText {
            id: sectionLabel

            visible: item.modelData.showHeader
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.small
            y: Tokens.spacing.small
            text: item.modelData.group
            color: Colours.palette.m3primary
            font: Tokens.font.label.large
        }

        Item {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 56

            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.large
                color: Colours.palette.m3secondaryContainer
                opacity: item.selected ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }

            StateLayer {
                radius: Tokens.rounding.large
                color: item.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                onClicked: item.clicked()
                onDoubleClicked: item.doubleClicked()
            }

            // Vignette : image, pastille de couleur ou icône du type.
            StyledRect {
                id: thumb

                anchors.left: parent.left
                anchors.leftMargin: Tokens.padding.small
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 40
                implicitHeight: 40
                radius: Tokens.rounding.medium
                color: item.modelData.kind === "colour" ? item.modelData.preview.trim() : Colours.tPalette.m3surfaceContainerHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: item.modelData.kind !== "colour" && !thumbImg.visible
                    text: root.kindIcons[item.modelData.kind] ?? "notes"
                    color: item.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                ClipRect {
                    anchors.fill: parent
                    radius: parent.radius
                    visible: thumbImg.status === Image.Ready

                    Image {
                        id: thumbImg

                        anchors.fill: parent
                        visible: item.modelData.kind === "image"
                        source: visible ? WallStudio.fileUrl(Clipboard.imageFor(item.modelData)) : ""
                        sourceSize: Qt.size(80, 80)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
            }

            ColumnLayout {
                anchors.left: thumb.right
                anchors.right: pinIcon.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.spacing.medium
                anchors.rightMargin: Tokens.spacing.small
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: item.modelData.kind === "image" ? `Image ${item.modelData.width}×${item.modelData.height}` : item.modelData.preview
                    color: item.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font: item.modelData.kind === "code" ? Tokens.font.mono.small : Tokens.font.body.medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        Clipboard.meta;
                        const parts = [Clipboard.relativeTime(Clipboard.timeOf(item.modelData)), Clipboard.appOf(item.modelData)];
                        return parts.filter(p => p).join(" · ") || (item.modelData.kind === "image" ? (item.modelData.size ?? "") : "");
                    }
                    color: item.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }

            MaterialIcon {
                id: pinIcon

                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.medium
                anchors.verticalCenter: parent.verticalCenter
                text: "keep"
                fill: 1
                visible: !!item.modelData.pinKey
                width: visible ? implicitWidth : 0
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.small
            }
        }
    }
}
