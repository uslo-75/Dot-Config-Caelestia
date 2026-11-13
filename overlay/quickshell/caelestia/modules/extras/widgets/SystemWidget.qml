pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services
import qs.utils

// Processeur, carte graphique, mémoire et disque : part utilisée, et température quand elle
// est connue.
Item {
    id: root

    readonly property var rows: [
        {
            icon: "memory",
            name: "Processeur",
            value: Cpu.percentage,
            temp: Cpu.temperature
        },
        {
            icon: "desktop_windows",
            name: "Graphique",
            value: Gpu.percentage,
            temp: Gpu.temperature
        },
        {
            icon: "memory_alt",
            name: "Mémoire",
            value: Memory.percentage,
            temp: NaN
        },
        {
            icon: "hard_disk",
            name: "Disque",
            value: Storage.percentage,
            temp: NaN
        }
    ]

    implicitWidth: 260
    implicitHeight: column.implicitHeight + Tokens.padding.large * 2

    ServiceRef {
        service: Cpu
    }

    ServiceRef {
        service: Gpu
    }

    ServiceRef {
        service: Memory
    }

    ServiceRef {
        service: Storage
    }

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        Repeater {
            model: root.rows

            Column {
                id: line

                required property var modelData
                readonly property real value: isNaN(modelData.value) ? 0 : Math.max(0, Math.min(1, modelData.value))

                width: parent.width
                spacing: 3

                Row {
                    width: parent.width
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        id: icon

                        anchors.verticalCenter: parent.verticalCenter
                        text: line.modelData.icon
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - icon.width - figures.width - parent.spacing * 2
                        text: line.modelData.name
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        id: figures

                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const pct = isNaN(line.modelData.value) ? "…" : Strings.percentOne(line.value);
                            return isNaN(line.modelData.temp) || line.modelData.temp <= 0 ? pct : `${pct}  ·  ${Math.round(line.modelData.temp)} °C`;
                        }
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }

                StyledRect {
                    width: parent.width
                    implicitHeight: 5
                    radius: 3
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.12)

                    StyledRect {
                        width: Math.round(parent.width * line.value)
                        height: parent.height
                        radius: 3
                        color: line.value > 0.9 ? Colours.palette.m3error : Colours.palette.m3primary
                    }
                }
            }
        }
    }
}
