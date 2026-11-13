pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Un widget de bureau : fond arrondi, contenu selon son type, position en fraction de la zone
// libre (0 à 1, pour rester entier à l'écran quelle que soit sa taille). En mode déplacement,
// il se glisse à la souris et sa croix le masque.
Item {
    id: root

    required property int modelData // Indice dans Extras.widgets.items.
    required property Item area

    readonly property var conf: Extras.widgets.items[modelData] ?? ({})
    readonly property real s: Math.max(0.5, Math.min(2, Extras.widgets.scale))
    readonly property real posX: Math.round(Math.max(0, Math.min(1, conf.x ?? 0)) * Math.max(0, area.width - width))
    readonly property real posY: Math.round(Math.max(0, Math.min(1, conf.y ?? 0)) * Math.max(0, area.height - height))
    readonly property bool editing: Extras.editingWidgets

    x: posX
    y: posY
    width: Math.round(content.implicitWidth * s)
    height: Math.round(content.implicitHeight * s)

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: Qt.alpha(Colours.palette.m3surfaceContainer, Math.max(0, Math.min(1, Extras.widgets.opacity)))
        border.width: root.editing ? 2 : 0
        border.color: Colours.palette.m3primary
    }

    Loader {
        id: content

        transformOrigin: Item.TopLeft
        scale: root.s
        enabled: !root.editing
        sourceComponent: {
            switch (root.conf.type) {
            case "clock":
                return clock;
            case "weather":
                return weather;
            case "system":
                return system;
            case "media":
                return media;
            case "calendar":
                return calendar;
            case "timer":
                return timer;
            }
            return null;
        }
    }

    Component {
        id: clock

        ClockWidget {}
    }

    Component {
        id: weather

        WeatherWidget {}
    }

    Component {
        id: system

        SystemWidget {}
    }

    Component {
        id: media

        MediaWidget {}
    }

    Component {
        id: calendar

        CalendarWidget {}
    }

    Component {
        id: timer

        TimerWidget {}
    }

    // Mode déplacement : le widget suit la souris, puis sa position est enregistrée.
    MouseArea {
        anchors.fill: parent
        enabled: root.editing
        visible: root.editing
        cursorShape: Qt.SizeAllCursor
        drag.target: root
        drag.minimumX: 0
        drag.maximumX: Math.max(0, root.area.width - root.width)
        drag.minimumY: 0
        drag.maximumY: Math.max(0, root.area.height - root.height)
        onReleased: {
            Extras.setWidget(root.modelData, {
                x: root.area.width > root.width ? root.x / (root.area.width - root.width) : 0,
                y: root.area.height > root.height ? root.y / (root.area.height - root.height) : 0
            });
            root.x = Qt.binding(() => root.posX);
            root.y = Qt.binding(() => root.posY);
        }
    }

    // Masquer ce widget (il se réactive dans les réglages).
    StyledRect {
        visible: root.editing
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: -8
        implicitWidth: 24
        implicitHeight: 24
        radius: 12
        color: Colours.palette.m3primary

        MaterialIcon {
            anchors.centerIn: parent
            text: "close"
            color: Colours.palette.m3onPrimary
            fontStyle: Tokens.font.icon.small
        }

        StateLayer {
            radius: parent.radius
            color: Colours.palette.m3onPrimary
            onClicked: Extras.setWidget(root.modelData, {
                enabled: false
            })
        }
    }
}
