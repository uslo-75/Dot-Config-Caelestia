import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Météo du moment (service météo du shell).
Item {
    implicitWidth: row.implicitWidth + Tokens.padding.extraLarge * 2
    implicitHeight: row.implicitHeight + Tokens.padding.large * 2

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.icon
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.extraLarge
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                text: Weather.temp
                font: Tokens.font.title.large
            }

            StyledText {
                text: Weather.description
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }

            StyledText {
                visible: text !== ""
                text: Weather.city
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }
}
