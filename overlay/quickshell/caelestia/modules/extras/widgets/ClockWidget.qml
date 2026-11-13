import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Heure et date.
Item {
    implicitWidth: column.implicitWidth + Tokens.padding.extraLarge * 2
    implicitHeight: column.implicitHeight + Tokens.padding.large * 2

    Column {
        id: column

        anchors.centerIn: parent
        spacing: 0

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: `${Time.hourStr}:${Time.minuteStr}`
            color: Colours.palette.m3primary
            font: Tokens.font.headline.builders.medium.size(64).weight(Font.DemiBold).build()
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.format("dddd d MMMM")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.title.small
        }
    }
}
