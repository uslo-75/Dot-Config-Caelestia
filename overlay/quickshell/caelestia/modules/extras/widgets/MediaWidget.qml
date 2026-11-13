import QtQuick
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Lecteur en cours : pochette, titre, artiste et commandes.
Item {
    id: root

    readonly property var player: Players.active

    implicitWidth: 300
    implicitHeight: row.implicitHeight + Tokens.padding.large * 2

    Row {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        ClipRect {
            id: cover

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 64
            implicitHeight: 64
            radius: Tokens.rounding.medium
            color: Qt.alpha(Colours.palette.m3onSurface, 0.1)

            MaterialIcon {
                anchors.centerIn: parent
                text: "music_note"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.large
            }

            Image {
                anchors.fill: parent
                source: Players.getArtUrl(root.player)
                sourceSize: Qt.size(128, 128)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - cover.width - parent.spacing
            spacing: 0

            StyledText {
                width: parent.width
                text: root.player ? (root.player.trackTitle || "Titre inconnu") : "Aucun lecteur"
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: !!root.player
                text: root.player?.trackArtist || "Artiste inconnu"
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            Row {
                visible: !!root.player
                spacing: Tokens.spacing.extraSmall

                IconButton {
                    type: IconButton.Text
                    icon: "skip_previous"
                    disabled: !root.player?.canGoPrevious
                    onClicked: root.player?.previous()
                }

                IconButton {
                    type: IconButton.Text
                    icon: root.player?.isPlaying ? "pause" : "play_arrow"
                    onClicked: root.player?.togglePlaying()
                }

                IconButton {
                    type: IconButton.Text
                    icon: "skip_next"
                    disabled: !root.player?.canGoNext
                    onClicked: root.player?.next()
                }
            }
        }
    }
}
