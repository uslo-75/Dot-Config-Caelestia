pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Shaders
import qs.components
import qs.components.controls
import qs.services

// Sélecteur de transition : chaque tuile montre l'effet figé à mi-parcours entre le fond actuel
// et le fond sélectionné, et le joue en boucle au survol (mêmes shaders que le bureau).
Item {
    id: root

    property bool shown
    property string fromSource
    property string toSource

    readonly property int columns: Math.max(3, Math.floor((width - Tokens.padding.large * 2 + Tokens.spacing.small) / 230))

    signal closed

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

    // Absorbe clics et molette pour ne pas toucher le carrousel en dessous.
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

    // Textures partagées par toutes les tuiles.
    Image {
        id: fromImg

        width: 240
        height: 135
        source: root.fromSource
        sourceSize: Qt.size(240, 135)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Image {
        id: toImg

        width: 240
        height: 135
        source: root.toSource
        sourceSize: Qt.size(240, 135)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    ShaderEffectSource {
        id: fromTex

        sourceItem: fromImg
        hideSource: true
    }

    ShaderEffectSource {
        id: toTex

        sourceItem: toImg
        hideSource: true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: "auto_awesome_motion"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: "Transition entre les fonds"
                    font: Tokens.font.title.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "Survole une tuile pour voir l'effet · « Aléatoire » en tire une différente à chaque changement"
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

        Flickable {
            id: flick

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: grid.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            GridLayout {
                id: grid

                width: flick.width
                columns: root.columns
                rowSpacing: Tokens.spacing.small
                columnSpacing: Tokens.spacing.small

                Repeater {
                    model: ["random", ...WallStudio.transitions]

                    Tile {}
                }
            }
        }
    }

    component Tile: StyledRect {
        id: tile

        required property string modelData
        readonly property bool selected: WallStudio.transition === modelData
        readonly property bool isRandom: modelData === "random"
        readonly property var shader: isRandom ? undefined : Shaders[modelData]

        Layout.fillWidth: true
        implicitHeight: 64
        radius: selected ? Tokens.rounding.medium : Tokens.rounding.large
        color: selected ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

        StateLayer {
            id: tileState

            radius: tile.radius
            color: tile.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            onClicked: {
                WallStudio.setTransition(tile.modelData);
                root.closed();
            }
        }

        ClipRect {
            id: thumb

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.small
            width: 85
            height: 48
            radius: Tokens.rounding.small
            color: Colours.tPalette.m3surfaceContainerHighest

            Loader {
                anchors.fill: parent
                active: !tile.isRandom && root.shown && tile.shader !== undefined

                sourceComponent: ShaderEffect {
                    id: effect

                    property Item from: fromTex
                    property Item to: toTex
                    property real progress: 0.42

                    fragmentShader: tile.shader.url

                    SequentialAnimation on progress {
                        running: tileState.containsMouse
                        loops: Animation.Infinite
                        onRunningChanged: {
                            if (!running)
                                effect.progress = 0.42;
                        }

                        NumberAnimation {
                            from: 0
                            to: 1
                            duration: Math.max(600, tile.shader.duration)
                            easing: tile.shader.easing
                        }
                        PauseAnimation {
                            duration: 450
                        }
                    }
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: tile.isRandom
                text: "casino"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.large
                rotation: tileState.containsMouse ? 360 : 0

                Behavior on rotation {
                    Anim {
                        type: Anim.SlowSpatial
                    }
                }
            }
        }

        ColumnLayout {
            anchors.left: thumb.right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.spacing.medium
            anchors.rightMargin: Tokens.padding.small
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: WallStudio.transitionName(tile.modelData)
                color: tile.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                font: Tokens.font.label.large
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: tile.isRandom || tile.selected
                text: tile.isRandom ? `${WallStudio.randomPool.length} effets doux en rotation` : "Sélectionnée"
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
