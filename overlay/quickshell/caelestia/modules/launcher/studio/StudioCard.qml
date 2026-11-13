pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.Models
import Caelestia.Multimedia
import Caelestia.State
import qs.components
import qs.components.effects
import qs.services

// Carte du carrousel : affiche, mini-clip vidéo au survol/sélection, badges.
Item {
    id: root

    required property FileSystemEntry modelData
    required property int index
    required property real cardWidth
    required property real cardHeight

    readonly property string path: modelData.path
    readonly property bool isCurrent: PathView.isCurrentItem
    readonly property bool isVideo: WallStudio.isVideo(path)
    readonly property bool isActual: path === Wallpapers.actualCurrent
    readonly property bool isFavourite: WallStudio.favourites.includes(path)
    readonly property bool hasTheme: {
        WallStudio.themes;
        return WallStudio.hasTheme(path);
    }
    readonly property string poster: WallStudio.posterFor(path)
    readonly property string clip: WallStudio.previewFor(path)
    readonly property real dim: PathView.itemDim ?? 0 // qmllint disable missing-property

    // Le mini-clip attend que la sélection se pose (créer un lecteur à chaque cran saccade).
    property bool settled

    signal activated

    onIsCurrentChanged: {
        settled = false;
        if (isCurrent)
            settleTimer.restart();
    }

    Timer {
        id: settleTimer

        interval: 380
        onTriggered: root.settled = root.isCurrent
    }

    Timer {
        id: hoverTimer

        interval: 380
        running: stateLayer.containsMouse && !root.isCurrent
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

        // Mini-clip (270p, 6 s) : seulement pour la carte sélectionnée ou survolée.
        Loader {
            anchors.fill: parent
            active: root.isVideo && root.clip !== "" && PersistentState.wallpaperPlaying && ((root.isCurrent && root.settled) || (stateLayer.containsMouse && !hoverTimer.running))

            sourceComponent: Visual {
                source: root.clip
                playing: true
            }
        }

        // Dégradé bas pour la lisibilité des badges.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 0.4
            opacity: root.isActual || root.hasTheme ? 0.75 : 0
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

        // Assombrit les cartes éloignées du centre.
        Rectangle {
            anchors.fill: parent
            color: Colours.palette.m3scrim
            opacity: root.dim * 0.5
        }
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
            text: (WallStudio.items[root.path]?.height ?? 0) >= 2160 ? "4K" : ""
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
                root.PathView.view.currentIndex = root.index;
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
