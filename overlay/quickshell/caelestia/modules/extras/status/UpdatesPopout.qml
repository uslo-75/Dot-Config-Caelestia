pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.studio
import qs.modules.extras.status

// Bulle des mises à jour : résumé, premiers paquets, et accès à la page des réglages.
Column {
    id: root

    readonly property var first: [...Updates.repo, ...Updates.aur, ...Updates.flatpak].slice(0, 6)

    spacing: Tokens.spacing.small
    width: 320

    StyledText {
        text: Updates.count > 0 ? `${Updates.count} mise${Updates.count > 1 ? "s" : ""} à jour` : "Système à jour"
        font: Tokens.font.title.small
    }

    StyledText {
        width: parent.width
        text: [Updates.summary, Updates.checking ? "vérification…" : Updates.lastCheckText].filter(t => t !== "").join("  ·  ")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
        elide: Text.ElideRight
    }

    StyledText {
        visible: Updates.shellStale
        width: parent.width
        text: "Le paquet du shell a changé : la copie modifiée est à reconstruire."
        color: Colours.palette.m3error
        font: Tokens.font.body.small
        wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width
        spacing: 0

        Repeater {
            model: root.first

            Row {
                id: line

                required property var modelData

                width: parent.width
                spacing: Tokens.spacing.small

                StyledText {
                    width: Math.round(parent.width * 0.55)
                    text: line.modelData.name
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width - Math.round(parent.width * 0.55) - parent.spacing
                    text: line.modelData.to
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
            }
        }

        StyledText {
            visible: Updates.count > root.first.length
            text: `et ${Updates.count - root.first.length} autres…`
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }

    Row {
        spacing: Tokens.spacing.small

        StudioChip {
            visible: Updates.count > 0
            icon: "download"
            text: "Tout mettre à jour"
            checked: true
            onClicked: Updates.upgrade()
        }

        StudioChip {
            icon: "list"
            text: "Détails"
            onClicked: ExtraStatus.openSettings("update")
        }

        StudioChip {
            icon: "refresh"
            text: "Vérifier"
            onClicked: Updates.check()
        }
    }
}
