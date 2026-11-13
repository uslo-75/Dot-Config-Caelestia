import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Puce de filtre / bouton de réglage du studio et du presse-papiers.
StyledRect {
    id: root

    property string icon
    property string text
    property string trailing
    property string trailingIcon
    property bool checked
    readonly property color onColour: checked ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant

    signal clicked

    implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: Math.max(row.implicitHeight + Tokens.padding.small * 2, 36)
    radius: checked ? Tokens.rounding.medium : Tokens.rounding.full
    color: checked ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

    StateLayer {
        radius: root.radius
        color: root.onColour
        onClicked: root.clicked()
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            fill: root.checked ? 1 : 0
            color: root.onColour
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.checked ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            font: Tokens.font.label.large
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.trailing !== ""
            text: root.trailing
            color: root.onColour
            opacity: 0.75
            font: Tokens.font.label.medium
        }

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.trailingIcon !== ""
            text: root.trailingIcon
            color: root.onColour
            fontStyle: Tokens.font.icon.small
        }
    }

    Behavior on radius {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
