pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Mises à jour du système : paquets en attente (dépôts, AUR, Flatpak), vérification et
// lancement de la mise à jour dans un terminal, et réglages (section `updates` d'extras.json).
PageBase {
    id: root

    readonly property var groups: [
        {
            title: "Dépôts officiels",
            packages: Updates.repo
        },
        {
            title: "AUR",
            packages: Updates.aur
        },
        {
            title: "Flatpak",
            packages: Updates.flatpak
        }
    ].filter(g => g.packages.length > 0)

    title: Tr.tr("Updates")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // État et actions
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: summary.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: summary

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: Updates.count > 0 ? "system_update_alt" : "check_circle"
                    color: Updates.count > 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Updates.count > 0 ? `${Updates.count} mise${Updates.count > 1 ? "s" : ""} à jour disponible${Updates.count > 1 ? "s" : ""}` : "Le système est à jour"
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: [Updates.summary, Updates.checking ? "vérification en cours…" : Updates.lastCheckText].filter(t => t !== "").join("  ·  ")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                IconTextButton {
                    visible: Updates.count > 0
                    icon: "download"
                    text: "Tout mettre à jour"
                    isRound: true
                    onClicked: Updates.upgrade()
                }

                IconButton {
                    type: IconButton.Tonal
                    icon: "refresh"
                    disabled: Updates.checking
                    onClicked: Updates.check()
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            visible: Updates.count > 0
            text: `« Tout mettre à jour » ouvre un terminal avec : ${Updates.command}`
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !Updates.hasCheckupdates
            text: "Sans le paquet pacman-contrib (checkupdates), seules les mises à jour déjà connues de pacman sont listées."
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        // Le paquet du shell a été mis à jour : la copie modifiée masque la nouvelle version.
        ConnectedRect {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            visible: Updates.shellStale
            first: true
            last: true
            color: Colours.palette.m3errorContainer
            implicitHeight: stale.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: stale

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "sync_problem"
                    color: Colours.palette.m3onErrorContainer
                    fontStyle: Tokens.font.icon.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: "Copie modifiée du shell à reconstruire"
                        color: Colours.palette.m3onErrorContainer
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: `Le paquet installé est ${Updates.shellPackage}, mais ta copie vient de ${Updates.shellBuiltFrom} et masque la nouvelle version.`
                        color: Colours.palette.m3onErrorContainer
                        font: Tokens.font.label.small
                        wrapMode: Text.WordWrap
                    }
                }

                IconTextButton {
                    visible: Updates.repoPath !== ""
                    icon: "build"
                    text: "Reconstruire"
                    isRound: true
                    onClicked: Updates.rebuildShell()
                }
            }
        }

        // Paquets en attente, par source
        Repeater {
            model: root.groups

            ColumnLayout {
                id: group

                required property var modelData

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    text: `${group.modelData.title} (${group.modelData.packages.length})`
                }

                Repeater {
                    model: group.modelData.packages

                    ConnectedRect {
                        id: row

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        first: index === 0
                        last: index === group.modelData.packages.length - 1
                        implicitHeight: line.implicitHeight + Tokens.padding.small * 2

                        RowLayout {
                            id: line

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.largeIncreased
                            anchors.rightMargin: Tokens.padding.largeIncreased
                            spacing: Tokens.spacing.medium

                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.maximumWidth: Math.round(row.width * 0.55)
                                text: row.modelData.from ? `${row.modelData.from}  →  ${row.modelData.to}` : row.modelData.to
                                color: Colours.palette.m3outline
                                font: Tokens.font.label.small
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }
            }
        }

        // Réglages
        SectionHeader {
            text: "Réglages"
        }

        ToggleRow {
            first: true
            text: "Vérification automatique"
            subtext: "Sinon seulement avec le bouton d'actualisation"
            checked: Extras.updates.enabled
            onToggled: Extras.updates.enabled = checked
        }

        StepperRow {
            label: "Minutes entre deux vérifications"
            value: Extras.updates.interval
            from: 15
            to: 1440
            stepSize: 15
            onMoved: v => Extras.updates.interval = v
        }

        ToggleRow {
            text: "Paquets de l'AUR"
            subtext: Updates.helper ? `Avec ${Updates.helper}` : "Demande yay ou paru"
            checked: Extras.updates.aur
            onToggled: Extras.updates.aur = checked
        }

        ToggleRow {
            text: "Applications Flatpak"
            checked: Extras.updates.flatpak
            onToggled: Extras.updates.flatpak = checked
        }

        ToggleRow {
            text: "Témoin dans la barre"
            subtext: "Affiché seulement quand des mises à jour attendent"
            checked: Extras.updates.showInBar
            onToggled: Extras.updates.showInBar = checked
        }

        ToggleRow {
            text: "Notification"
            subtext: "Quand de nouvelles mises à jour arrivent"
            checked: Extras.updates.notify
            onToggled: Extras.updates.notify = checked
        }

        TextFieldRow {
            last: true
            label: "Commande de mise à jour"
            subtext: "Vide : choisie d'après les outils installés"
            value: Extras.updates.command
            placeholderText: Updates.helper ? `${Updates.helper} -Syu` : "sudo pacman -Syu"
            onEditingFinished: value => Extras.updates.command = value.trim()
        }
    }
}
