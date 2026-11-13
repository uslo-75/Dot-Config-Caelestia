pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.Models
import Caelestia.State
import qs.components
import qs.components.effects
import qs.services

// Carte du carrousel : affiche, mini-clip au survol/sélection, badges.
Item {
    id: root

    required property FileSystemEntry modelData
    required property int index
    required property real cardWidth
    required property real cardHeight

    readonly property string path: modelData.path
    readonly property bool isCurrent: PathView.isCurrentItem
    readonly property var meta: WallStudio.items[path] ?? null
    readonly property bool isVideo: WallStudio.isVideo(path)
    // Fond affiché par l'écran visé dans le studio.
    property string targetWall
    readonly property bool isActual: path === targetWall
    readonly property bool isFavourite: WallStudio.favourites.includes(path)
    readonly property bool hasTheme: {
        WallStudio.themes;
        return WallStudio.hasTheme(path);
    }
    readonly property string poster: WallStudio.posterFor(path)
    readonly property string strip: meta?.strip ?? ""
    readonly property real dim: PathView.itemDim ?? 0 // qmllint disable missing-property

    // Le mini-clip attend que la carte se pose au centre, ou un survol qui dure.
    property bool settled
    property bool hoverSettled
    readonly property bool hovered: stateLayer.containsMouse && !isCurrent
    readonly property bool showClip: strip !== "" && PersistentState.wallpaperPlaying && ((isCurrent && settled) || (hovered && hoverSettled))

    signal activated
    signal picked

    onIsCurrentChanged: {
        settled = false;
        if (isCurrent)
            settleTimer.restart();
        else
            settleTimer.stop();
    }

    onHoveredChanged: {
        hoverSettled = false;
        if (hovered)
            hoverTimer.restart();
        else
            hoverTimer.stop();
    }

    Component.onCompleted: {
        if (isCurrent)
            settleTimer.restart();
    }

    Timer {
        id: settleTimer

        interval: 260
        onTriggered: root.settled = root.isCurrent
    }

    Timer {
        id: hoverTimer

        interval: 320
        onTriggered: root.hoverSettled = root.hovered
    }

    width: cardWidth
    height: cardHeight
    z: PathView.itemZ ?? 0 // qmllint disable missing-property
    scale: PathView.itemScale ?? 1 // qmllint disable missing-property
    opacity: PathView.onPath ? 1 : 0

    transform: Rotation {
        origin.x: root.width / 2
        origin.y: root.height / 2
        axis.x: 0
        axis.y: 1
        axis.z: 0
        angle: root.PathView.itemAngle ?? 0 // qmllint disable missing-property
    }

    Elevation {
        anchors.fill: frame
        radius: frame.radius
        level: root.isCurrent ? 4 : 2
        opacity: 1 - root.dim * 0.6
    }

    // Le contenu du ClipRect est rendu dans une texture : tant que rien n'y change, la carte
    // n'est pas redessinée. Tout ce qui varie pendant le défilement (assombrissement, badges)
    // reste donc en dehors.
    ClipRect {
        id: frame

        anchors.fill: parent
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerHigh

        MaterialIcon {
            anchors.centerIn: parent
            text: root.isVideo ? "movie" : "image"
            color: Colours.palette.m3outline
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.5).build()
        }

        Image {
            anchors.fill: parent
            source: WallStudio.fileUrl(root.poster)
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: {
                const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
                return Qt.size(Math.round(root.cardWidth * dpr), Math.round(root.cardHeight * dpr));
            }
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // Mini-clip (planche d'images) : seulement pour la carte sélectionnée ou survolée.
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

        // Dégradé bas pour la lisibilité des badges.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 0.4
            visible: root.isActual || root.hasTheme
            opacity: 0.75
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Colours.palette.m3scrim, 0.7)
                }
            }
        }
    }

    // Assombrit les cartes éloignées du centre.
    Rectangle {
        anchors.fill: frame
        radius: frame.radius
        color: Colours.palette.m3scrim
        opacity: root.dim * 0.5
        visible: opacity > 0
    }

    Row {
        anchors.left: frame.left
        anchors.top: frame.top
        anchors.margins: Tokens.padding.small
        spacing: Tokens.spacing.extraSmall
        opacity: 1 - root.dim * 0.7

        Badge {
            visible: root.isVideo
            icon: "play_arrow"
            text: (root.meta?.height ?? 0) >= 2160 ? "4K" : ""
        }
    }

    Badge {
        anchors.right: frame.right
        anchors.top: frame.top
        anchors.margins: Tokens.padding.small
        visible: root.isFavourite
        icon: "star"
        filled: true
        accent: true
        opacity: 1 - root.dim * 0.7
    }

    Row {
        anchors.left: frame.left
        anchors.bottom: frame.bottom
        anchors.margins: Tokens.padding.small
        spacing: Tokens.spacing.extraSmall
        opacity: 1 - root.dim * 0.7

        Badge {
            visible: root.isActual
            icon: "check_circle"
            text: "Actuel"
            filled: true
            accent: true
        }

        Badge {
            visible: root.hasTheme
            icon: "palette"
        }
    }

    StateLayer {
        id: stateLayer

        anchors.fill: frame
        radius: frame.radius
        color: Colours.palette.m3onSurface
        onClicked: {
            if (root.isCurrent)
                root.activated();
            else
                root.picked();
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
