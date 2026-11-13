pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

// Liste de résultats commune aux modes ajoutés au launcher (fichiers, web…) : une ligne par
// entrée { title, subtitle, icon | glyph, trailing }, navigation au clavier, Entrée pour valider.
Item {
    id: root

    required property var entries
    required property real maxHeight
    property string emptyIcon: "manage_search"
    property string emptyTitle: "Aucun résultat"
    property string emptyText: "Essaie une autre recherche"

    readonly property var current: entries[view.currentIndex] ?? null
    readonly property int rowHeight: Tokens.sizes.launcher.itemHeight

    signal activated(entry: var, modifiers: int)

    function handleKey(event: KeyEvent): bool {
        switch (event.key) {
        case Qt.Key_Up:
            view.decrementCurrentIndex();
            return true;
        case Qt.Key_Down:
            view.incrementCurrentIndex();
            return true;
        case Qt.Key_PageUp:
            view.currentIndex = Math.max(0, view.currentIndex - 5);
            return true;
        case Qt.Key_PageDown:
            view.currentIndex = Math.min(view.count - 1, view.currentIndex + 5);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (current)
                activated(current, event.modifiers);
            return true;
        }
        return false;
    }

    implicitWidth: Tokens.sizes.launcher.itemWidth
    implicitHeight: view.count > 0 ? Math.min(maxHeight, (rowHeight + view.spacing) * Math.min(Config.launcher.maxShown, view.count) - view.spacing) : empty.implicitHeight

    onEntriesChanged: view.currentIndex = 0

    StyledListView {
        id: view

        anchors.fill: parent
        clip: true
        spacing: Tokens.spacing.small
        model: root.entries
        highlightMoveDuration: 0

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            width: ListView.view.width
            implicitHeight: root.rowHeight

            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.large
                color: row.ListView.isCurrentItem ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : "transparent"
            }

            StateLayer {
                radius: Tokens.rounding.large
                onClicked: {
                    view.currentIndex = row.index;
                    root.activated(row.modelData, 0);
                }
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium

                Item {
                    id: leading

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: root.rowHeight * 0.64
                    implicitHeight: implicitWidth

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !row.modelData.glyph
                        text: row.modelData.icon ?? "draft"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.large
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: !!row.modelData.glyph
                        text: row.modelData.glyph ?? ""
                        font: Tokens.font.title.large
                    }
                }

                Column {
                    anchors.left: leading.right
                    anchors.right: trailing.left
                    anchors.leftMargin: Tokens.spacing.medium
                    anchors.rightMargin: Tokens.spacing.medium
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        width: parent.width
                        text: row.modelData.title ?? ""
                        font: Tokens.font.body.medium
                        elide: Text.ElideMiddle
                    }

                    StyledText {
                        width: parent.width
                        visible: text !== ""
                        text: row.modelData.subtitle ?? ""
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                        elide: Text.ElideMiddle
                    }
                }

                StyledText {
                    id: trailing

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.trailing ?? ""
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }
    }

    Row {
        id: empty

        anchors.centerIn: parent
        visible: view.count === 0
        spacing: Tokens.spacing.medium
        padding: Tokens.padding.large

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.emptyIcon
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.extraLarge
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: root.emptyTitle
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.large.weight(Font.Medium).build()
            }

            StyledText {
                text: root.emptyText
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
            }
        }
    }
}
