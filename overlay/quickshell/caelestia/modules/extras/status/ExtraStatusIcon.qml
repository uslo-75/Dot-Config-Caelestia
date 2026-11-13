pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Un témoin des ajouts dans la colonne d'icônes d'état de la barre. `name` est aussi le nom de
// la bulle ouverte au survol (voir modules/bar/popouts/Content.qml).
Item {
    id: root

    required property string modelData
    readonly property string name: modelData
    property color colour: Colours.palette.m3secondary

    Layout.alignment: Qt.AlignHCenter
    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight

    Loader {
        id: loader

        anchors.centerIn: parent
        sourceComponent: root.name === "timer" ? timer : root.name === "updates" ? updates : gif
    }

    // Minuteur : anneau qui se vide, minutes restantes au centre (secondes sous la minute).
    Component {
        id: timer

        Item {
            implicitWidth: 26
            implicitHeight: 26

            CircularProgress {
                anchors.fill: parent
                value: Timers.active ? 1 - Timers.progress : 0
                strokeWidth: 3
                fgColour: root.colour
                bgColour: Qt.alpha(root.colour, 0.25)
            }

            StyledText {
                anchors.centerIn: parent
                visible: Timers.running
                text: Timers.shortText
                color: root.colour
                font: Tokens.font.label.small
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !Timers.running
                text: Timers.paused ? "pause" : "timer"
                color: root.colour
                fontStyle: Tokens.font.icon.small
            }
        }
    }

    // Mises à jour : icône et nombre de paquets.
    Component {
        id: updates

        Column {
            spacing: -2

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Updates.shellStale ? "sync_problem" : "system_update_alt"
                color: Updates.shellStale ? Colours.palette.m3error : root.colour
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Updates.count > 0
                text: Updates.count > 999 ? "999+" : String(Updates.count)
                color: root.colour
                font: Tokens.font.label.small
            }
        }
    }

    // Enregistrement d'un GIF en cours.
    Component {
        id: gif

        MaterialIcon {
            text: "gif_box"
            fill: 1
            color: Colours.palette.m3error
            fontStyle: Tokens.font.icon.medium
        }
    }
}
