import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.launcher.studio

// Bulle affichée pendant l'enregistrement d'un GIF.
Column {
    spacing: Tokens.spacing.small
    width: 260

    StyledText {
        text: "Enregistrement d'un GIF"
        font: Tokens.font.title.small
    }

    StyledText {
        width: parent.width
        text: `Il s'arrête seul au bout de ${Extras.capture.gifMaxSeconds} s.`
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
        wrapMode: Text.WordWrap
    }

    StudioChip {
        icon: "stop"
        text: "Arrêter et créer le GIF"
        checked: true
        onClicked: Capture.gifToggle()
    }
}
