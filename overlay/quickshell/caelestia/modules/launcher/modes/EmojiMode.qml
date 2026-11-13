pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

// Mode « emoji » du launcher (>emoji, >e ou raccourci) : grille d'emoji et de symboles Nerd
// Font. Entrée colle dans la fenêtre active, Maj+Entrée copie seulement.
Item {
    id: root

    required property var screenState
    required property string query
    required property real maxHeight
    property string keyword
    property var search

    readonly property var entries: Emojis.loaded ? Emojis.search(query) : []
    readonly property var current: entries[grid.currentIndex] ?? null
    readonly property int cell: 46
    readonly property int columns: 13

    function activate(copyOnly: bool): void {
        if (!current)
            return;
        Emojis.use(current, copyOnly);
        screenState.launcher = false;
    }

    function handleKey(event: KeyEvent): bool {
        switch (event.key) {
        case Qt.Key_Left:
            grid.moveCurrentIndexLeft();
            return true;
        case Qt.Key_Right:
            grid.moveCurrentIndexRight();
            return true;
        case Qt.Key_Up:
            grid.moveCurrentIndexUp();
            return true;
        case Qt.Key_Down:
            grid.moveCurrentIndexDown();
            return true;
        case Qt.Key_PageUp:
            grid.currentIndex = Math.max(0, grid.currentIndex - columns * 4);
            return true;
        case Qt.Key_PageDown:
            grid.currentIndex = Math.min(grid.count - 1, grid.currentIndex + columns * 4);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activate(event.modifiers & Qt.ShiftModifier);
            return true;
        }
        return false;
    }

    implicitWidth: columns * cell
    implicitHeight: Math.min(maxHeight, cell * 6 + footer.implicitHeight + Tokens.spacing.small)

    onEntriesChanged: grid.currentIndex = 0
    Component.onCompleted: Emojis.load()

    GridView {
        id: grid

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Tokens.spacing.small
        clip: true
        cellWidth: root.cell
        cellHeight: root.cell
        model: root.entries
        highlightMoveDuration: 0
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: tile

            required property var modelData
            required property int index

            width: root.cell
            height: root.cell

            StyledRect {
                anchors.fill: parent
                anchors.margins: 2
                radius: Tokens.rounding.medium
                color: tile.GridView.isCurrentItem ? Colours.palette.m3secondaryContainer : "transparent"
            }

            StateLayer {
                anchors.margins: 2
                radius: Tokens.rounding.medium
                onClicked: {
                    grid.currentIndex = tile.index;
                    root.activate(false);
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: tile.modelData.glyph
                // La police mono du shell contient les glyphes Nerd Font ; les emoji passent
                // par la police emoji du système.
                font: Tokens.font.mono.builders.medium.size(Math.min(20, 20 * 2 / Math.max(2, tile.modelData.glyph.length))).build()
            }
        }
    }

    Item {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        implicitHeight: name.implicitHeight + Tokens.padding.small

        StyledText {
            id: name

            anchors.left: parent.left
            anchors.right: hint.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.small
            anchors.rightMargin: Tokens.spacing.medium
            text: !Emojis.loaded ? "Chargement…" : root.current ? `${root.current.glyph}  ${root.current.name}` : "Aucun résultat (les noms sont en anglais : smile, heart, arrow…)"
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
            elide: Text.ElideRight
        }

        StyledText {
            id: hint

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Tokens.padding.small
            text: "⏎ coller   ⇧⏎ copier"
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }
}
