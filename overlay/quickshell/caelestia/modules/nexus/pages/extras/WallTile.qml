pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Components
import Caelestia.Config
import Caelestia.State
import qs.components
import qs.services
import qs.modules.launcher.studio

// Vignette d'un fond dans la galerie des réglages : affiche du fond, mini-clip au survol pour
// les fonds animés (planche d'aperçu du studio, sans lecteur vidéo), favori et fond actuel.
Item {
    id: root

    required property string path
    property string label: WallStudio.displayName(path)
    // Fond affiché par l'écran visé.
    property bool current

    readonly property var meta: WallStudio.items[path] ?? null
    readonly property bool video: WallStudio.isVideo(path)
    readonly property bool favourite: WallStudio.favourites.includes(path)
    readonly property string poster: WallStudio.posterFor(path)
    readonly property string strip: meta?.strip ?? ""
    readonly property bool hovered: stateLayer.containsMouse || star.hovered
    // Le mini-clip attend un survol qui dure : passer sur la grille ne charge rien.
    property bool hoverSettled
    readonly property bool showClip: strip !== "" && PersistentState.wallpaperPlaying && hovered && hoverSettled

    signal clicked

    onHoveredChanged: {
        hoverSettled = false;
        if (hovered)
            hoverTimer.restart();
        else
            hoverTimer.stop();
    }

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight

    Timer {
        id: hoverTimer

        interval: 250
        onTriggered: root.hoverSettled = root.hovered
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.extraSmall

        Item {
            id: frame

            Layout.fillWidth: true
            implicitHeight: Math.round(width * 9 / 16)

            ClipRect {
                anchors.fill: parent
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.video ? "movie" : "image"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.large
                }

                Image {
                    anchors.fill: parent
                    source: WallStudio.fileUrl(root.poster)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: {
                        const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
                        return Qt.size(Math.round(frame.width * dpr), Math.round(frame.height * dpr));
                    }
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: root.showClip

                    sourceComponent: ClipStrip {
                        source: root.strip
                        columns: root.meta?.stripCols ?? 10
                        frames: root.meta?.stripFrames ?? 1
                        fps: root.meta?.stripFps ?? 15
                    }
                }
            }

            // Contour du fond actuel.
            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.large
                color: "transparent"
                border.width: root.current ? 3 : 0
                border.color: Colours.palette.m3primary
            }

            Badge {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Tokens.padding.small
                visible: root.video
                icon: "play_arrow"
                text: (root.meta?.height ?? 0) >= 2160 ? "4K" : ""
            }

            Badge {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.padding.small
                visible: root.current
                icon: "check_circle"
                text: "Actuel"
                filled: true
                accent: true
            }

            StateLayer {
                id: stateLayer

                radius: Tokens.rounding.large
                color: Colours.palette.m3onSurface
                onClicked: root.clicked()
            }

            // Favori : toujours visible sur un favori, sinon au survol.
            Badge {
                id: star

                readonly property bool hovered: starArea.containsMouse

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.small
                visible: root.favourite || root.hovered
                icon: "star"
                filled: root.favourite
                accent: root.favourite

                StateLayer {
                    id: starArea

                    radius: parent.radius
                    color: Colours.palette.m3onSurface
                    onClicked: WallStudio.toggleFavourite(root.path)
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            text: root.label
            font: Tokens.font.label.medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.padding.small
            text: WallStudio.details(root.path).slice(1, 4).filter(d => !d.endsWith("i/s")).join("  ·  ")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    component Badge: StyledRect {
        id: badge

        property string icon
        property string text
        property bool filled
        property bool accent

        implicitWidth: badgeRow.implicitWidth + Tokens.padding.small * 2
        implicitHeight: badgeRow.implicitHeight + Tokens.padding.extraSmall * 2
        radius: Tokens.rounding.full
        color: accent ? Colours.palette.m3primaryContainer : Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.85)

        Row {
            id: badgeRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: badge.icon
                fill: badge.filled ? 1 : 0
                color: badge.accent ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: badge.text !== ""
                text: badge.text
                color: badge.accent ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                font: Tokens.font.label.small
            }
        }
    }
}
