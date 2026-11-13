pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.studio

// Minuteur en cours et ses commandes, ou durées à lancer.
Item {
    implicitWidth: 260
    implicitHeight: column.implicitHeight + Tokens.padding.large * 2

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        StyledText {
            text: Timers.active ? Timers.label : "Minuteur"
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.large
        }

        StyledText {
            visible: Timers.active
            text: Timers.text
            color: Timers.running ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.headline.medium
        }

        StyledRect {
            visible: Timers.active
            width: parent.width
            implicitHeight: 5
            radius: 3
            color: Qt.alpha(Colours.palette.m3onSurface, 0.12)

            StyledRect {
                width: Math.round(parent.width * Timers.progress)
                height: parent.height
                radius: 3
                color: Colours.palette.m3primary
            }
        }

        Row {
            visible: Timers.active
            spacing: Tokens.spacing.small

            IconButton {
                type: IconButton.Tonal
                icon: Timers.running ? "pause" : "play_arrow"
                onClicked: Timers.toggle()
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
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: Extras.timer.presets

                StudioChip {
                    required property var modelData

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
    }
}
