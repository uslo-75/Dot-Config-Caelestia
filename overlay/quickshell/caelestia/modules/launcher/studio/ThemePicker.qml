pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Couleurs mémorisées pour le fond sélectionné : mode + variante, avec les vraies pastilles
// de chaque variante calculées pour ce fond.
Item {
    id: root

    property bool shown
    property string path
    property var theme: ({
            mode: "auto",
            variant: "auto"
        })
    property var swatches: ({})
    readonly property string swatchKey: `${path}|${theme.mode}`
    readonly property var current: swatches[swatchKey] ?? null
    readonly property int columns: Math.max(3, Math.min(5, Math.floor((width - Tokens.padding.large * 2) / 220)))

    signal picked(mode: string, variant: string)
    signal closed

    function request(): void {
        if (!shown || !path || swatches[swatchKey] || (proc.running && proc.key === swatchKey))
            return;
        proc.key = swatchKey;
        const cmd = [WallStudio.applyTool, "--print", "--variants", "--tag", swatchKey, path, "--mode", theme.mode];
        if (!GlobalConfig.services.smartScheme)
            cmd.push("--no-smart");
        proc.exec(cmd);
    }

    function swatchFor(variant: string): var {
        if (!current)
            return null;
        if (variant === "auto")
            return current.variants?.[current.smartVariant ?? ""] ?? null;
        return current.variants?.[variant] ?? null;
    }

    onShownChanged: request()
    onSwatchKeyChanged: request()

    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.97
    visible: opacity > 0
    enabled: shown

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Behavior on scale {
        Anim {}
    }

    Process {
        id: proc

        property string key

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (data?.variants && data.tag)
                        root.swatches = Object.assign({}, root.swatches, {
                            [data.tag]: data
                        });
                } catch (e) {
                    // Sortie interrompue (fond changé entre-temps) : la prochaine demande suffira.
                }
                Qt.callLater(root.request);
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onWheel: e => e.accepted = true
    }

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: "palette"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.path ? `Couleurs de « ${WallStudio.displayName(root.path)} »` : "Couleurs"
                    font: Tokens.font.title.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "Mémorisées pour ce fond et appliquées dès que tu le choisis · « Auto » laisse Caelestia décider"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }

            IconButton {
                type: IconButton.Text
                icon: "close"
                onClicked: root.closed()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.preferredWidth: 90
                text: "Mode"
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.large
            }

            Repeater {
                model: WallStudio.modes

                StudioChip {
                    required property var modelData

                    icon: modelData.icon
                    text: modelData.key === "auto" && root.current && root.theme.mode === "auto" ? `Auto (${root.current.mode === "light" ? "clair" : "sombre"})` : modelData.name
                    checked: root.theme.mode === modelData.key
                    onClicked: root.picked(modelData.key, root.theme.variant)
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                visible: proc.running
                text: "Calcul des palettes…"
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
        }

        StyledText {
            text: "Variante"
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.large
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.columns
            rowSpacing: Tokens.spacing.small
            columnSpacing: Tokens.spacing.small

            Repeater {
                model: WallStudio.variants

                StyledRect {
                    id: tile

                    required property var modelData
                    readonly property bool selected: root.theme.variant === modelData.key
                    readonly property var colours: root.swatchFor(modelData.key)

                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: selected ? Tokens.rounding.medium : Tokens.rounding.large
                    color: selected ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

                    StateLayer {
                        radius: tile.radius
                        color: tile.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        onClicked: root.picked(root.theme.mode, tile.modelData.key)
                    }

                    // Pastilles : primaire, secondaire, tertiaire et conteneur.
                    Row {
                        id: dots

                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -6

                        Repeater {
                            model: ["primary", "secondary", "tertiary", "primaryContainer"]

                            Rectangle {
                                required property string modelData
                                required property int index

                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 11
                                z: 4 - index
                                border.width: 2
                                border.color: tile.color
                                color: tile.colours?.[modelData] ? `#${tile.colours[modelData]}` : Colours.palette.m3surfaceContainerHighest

                                Behavior on color {
                                    CAnim {}
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.left: dots.right
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.spacing.medium
                        anchors.rightMargin: Tokens.padding.small
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: tile.modelData.name
                            color: tile.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            font: Tokens.font.label.large
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: tile.modelData.key === "auto" && !!root.current?.smartVariant
                            text: WallStudio.variants.find(v => v.key === root.current?.smartVariant)?.name ?? ""
                            color: tile.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }
                    }

                    Behavior on radius {
                        Anim {
                            type: Anim.DefaultEffects
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
