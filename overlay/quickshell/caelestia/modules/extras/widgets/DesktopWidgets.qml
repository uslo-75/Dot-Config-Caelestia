pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

// Widgets de bureau d'un écran, posés sur le fond d'écran (dans la fenêtre du fond : aucune
// surface de plus). Types, écran et position de chacun : section `widgets` d'extras.json,
// modifiable dans les réglages (page « Extras ») ; le mode « déplacement » permet de les placer
// à la souris.
Item {
    id: root

    required property ShellScreen screen

    // Indices (dans Extras.widgets.items) des widgets de cet écran : une liste d'entiers ne
    // change pas quand seule une position est modifiée, donc rien n'est recréé.
    readonly property var shown: {
        const out = [];
        const items = Extras.widgets.items;
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (item?.enabled && (!item.screen || item.screen === screen.name))
                out.push(i);
        }
        return out;
    }

    // Zone libre : l'écran sans la barre ni le cadre du shell.
    Item {
        id: area

        anchors.fill: parent
        anchors.margins: Tokens.padding.extraLargeIncreased
        anchors.leftMargin: Tokens.padding.extraLargeIncreased + Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness)

        Repeater {
            model: ScriptModel {
                values: root.shown
            }

            WidgetFrame {
                area: area
            }
        }
    }

    // Mode déplacement : rappel et bouton pour en sortir.
    StyledRect {
        visible: Extras.editingWidgets
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Tokens.padding.extraLargeIncreased
        implicitWidth: banner.implicitWidth + Tokens.padding.large * 2
        implicitHeight: banner.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: Colours.palette.m3primaryContainer

        Row {
            id: banner

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "open_with"
                color: Colours.palette.m3onPrimaryContainer
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Glisse les widgets pour les placer · clique ici pour terminer"
                color: Colours.palette.m3onPrimaryContainer
                font: Tokens.font.label.large
            }
        }

        StateLayer {
            radius: parent.radius
            color: Colours.palette.m3onPrimaryContainer
            onClicked: Extras.editingWidgets = false
        }
    }
}
