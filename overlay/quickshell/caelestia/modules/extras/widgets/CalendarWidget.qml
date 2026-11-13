pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Mois en cours, semaine commençant le lundi, jour d'aujourd'hui mis en avant.
Item {
    id: root

    readonly property date today: Time.date
    readonly property int year: today.getFullYear()
    readonly property int month: today.getMonth()
    // Cases du mois : 0 pour les vides avant le 1er.
    readonly property var cells: {
        const first = (new Date(year, month, 1).getDay() + 6) % 7; // lundi = 0
        const days = new Date(year, month + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < first; i++)
            out.push(0);
        for (let d = 1; d <= days; d++)
            out.push(d);
        return out;
    }
    readonly property int cell: 30

    implicitWidth: cell * 7 + Tokens.padding.large * 2
    implicitHeight: column.implicitHeight + Tokens.padding.large * 2

    Column {
        id: column

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.format("MMMM yyyy")
            font: Tokens.font.title.small
        }

        Row {
            Repeater {
                model: ["L", "M", "M", "J", "V", "S", "D"]

                StyledText {
                    required property string modelData

                    width: root.cell
                    text: modelData
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Grid {
            columns: 7

            Repeater {
                model: root.cells

                Item {
                    id: day

                    required property int modelData
                    readonly property bool isToday: modelData === root.today.getDate()

                    width: root.cell
                    height: root.cell

                    StyledRect {
                        anchors.centerIn: parent
                        visible: day.isToday
                        width: root.cell - 4
                        height: root.cell - 4
                        radius: width / 2
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: day.modelData > 0
                        text: day.modelData
                        color: day.isToday ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        font: Tokens.font.label.medium
                    }
                }
            }
        }
    }
}
