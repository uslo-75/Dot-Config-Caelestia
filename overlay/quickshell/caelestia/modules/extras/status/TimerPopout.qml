pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.studio

// Bulle du minuteur : temps restant et commandes, ou durées à lancer quand rien ne tourne.
Column {
    id: root

    spacing: Tokens.spacing.medium
    width: 280

    StyledText {
        text: Timers.active ? Timers.label : "Minuteur"
        font: Tokens.font.title.small
    }

    StyledText {
        visible: Timers.active
        text: Timers.text
        color: Timers.running ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        font: Tokens.font.headline.medium
    }

    // Avancement de la phase en cours.
    StyledRect {
        visible: Timers.active
        width: parent.width
        implicitHeight: 6
        radius: 3
        color: Colours.palette.m3secondaryContainer

        StyledRect {
            width: Math.round(parent.width * Timers.progress)
            height: parent.height
            radius: 3
            color: Colours.palette.m3primary
        }
    }

    StyledText {
        visible: Timers.active && Timers.phase !== ""
        text: `Pomodoro ${Timers.cycle} sur ${Extras.timer.pomodoro.cycles}`
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    Row {
        visible: Timers.active
        spacing: Tokens.spacing.small

        IconButton {
            type: IconButton.Tonal
            icon: Timers.running ? "pause" : "play_arrow"
            onClicked: Timers.toggle()
        }

        StudioChip {
            anchors.verticalCenter: parent.verticalCenter
            text: "+1 min"
            onClicked: Timers.add(1)
        }

        StudioChip {
            anchors.verticalCenter: parent.verticalCenter
            text: "+5 min"
            onClicked: Timers.add(5)
        }

        IconButton {
            type: IconButton.Tonal
            icon: "stop"
            onClicked: Timers.stop()
        }
    }

    Flow {
        visible: !Timers.active
        width: parent.width
        spacing: Tokens.spacing.small

        Repeater {
            model: Extras.timer.presets

            StudioChip {
                required property var modelData

                icon: "timer"
                text: Timers.describe(modelData)
                onClicked: Timers.start(modelData, "")
            }
        }

        StudioChip {
            icon: "hourglass_top"
            text: "Pomodoro"
            onClicked: Timers.startPomodoro()
        }
    }

    StyledText {
        visible: !Timers.active
        width: parent.width
        text: "Ou dans le launcher : >timer 10, >timer 1h30…"
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
        elide: Text.ElideRight
    }
}
