pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// Miniature d'une fenêtre dans sa case : capture en direct, icône de l'appli, clic pour y
// aller, clic molette pour la fermer, glisser vers une autre case pour la déplacer.
Item {
    id: root

    required property HyprlandToplevel modelData
    required property var view // OverviewContent
    required property var cell // WorkspaceCell

    readonly property HyprlandToplevel toplevel: modelData
    readonly property var ipc: toplevel.lastIpcObject
    readonly property bool matching: view.matches(toplevel)
    readonly property bool selected: view.selectedWindow === toplevel
    readonly property bool dragging: view.dragWindow === toplevel

    // Rectangle de la fenêtre ramené dans la case, sans en sortir (une fenêtre en plein écran
    // déborde sur la zone de la barre).
    readonly property real boundW: cell.area.w * cell.fit
    readonly property real boundH: cell.area.h * cell.fit
    readonly property real rectX: Math.max(0, Math.min(boundW - 16, ((ipc?.at?.[0] ?? 0) - cell.area.x) * cell.fit))
    readonly property real rectY: Math.max(0, Math.min(boundH - 16, ((ipc?.at?.[1] ?? 0) - cell.area.y) * cell.fit))

    property real dragX
    property real dragY
    // Déposée sur une autre case : cachée le temps que Hyprland la déplace.
    property bool dropped
    property bool appeared
    // Fermeture demandée : la capture s'arrête d'abord (Quickshell peut planter quand une
    // fenêtre capturée disparaît).
    property bool closing

    x: cell.offsetX + rectX
    y: cell.offsetY + rectY
    width: Math.max(16, Math.min(boundW - rectX, (ipc?.size?.[0] ?? 0) * cell.fit))
    height: Math.max(16, Math.min(boundH - rectY, (ipc?.size?.[1] ?? 0) * cell.fit))
    z: dragging ? 100 : ipc?.fullscreen ? 3 : ipc?.floating ? 2 : 1
    opacity: dropped || !appeared ? 0 : matching ? 1 : 0.2
    scale: dragging ? 1.05 : appeared ? 1 : 0.9

    transform: Translate {
        x: root.dragX
        y: root.dragY
    }

    Component.onCompleted: appeared = true

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on dragX {
        enabled: !root.dragging

        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on dragY {
        enabled: !root.dragging

        Anim {
            type: Anim.FastSpatial
        }
    }

    // Si le déplacement n'a pas eu lieu, la miniature revient.
    Timer {
        id: dropTimer

        interval: 700
        onTriggered: root.dropped = false
    }

    // Fenêtre toujours là (demande de confirmation, par exemple) : la capture reprend.
    Timer {
        id: closeTimer

        interval: 2000
        onTriggered: root.closing = false
    }

    ClipRect {
        anchors.fill: parent
        radius: Tokens.rounding.small
        color: Colours.tPalette.m3surfaceContainerHighest

        ScreencopyView {
            id: shot

            anchors.fill: parent
            captureSource: root.view.shown && !root.closing ? root.toplevel.wayland : null
            live: root.view.conf.livePreviews
            onCaptureSourceChanged: {
                if (!live && captureSource)
                    captureFrame();
            }
        }

        // Voile au survol.
        Rectangle {
            anchors.fill: parent
            color: Colours.palette.m3onSurface
            opacity: mouse.pressed ? 0.16 : mouse.containsMouse ? 0.08 : 0
        }
    }

    // Sans aperçu en continu : une capture par seconde.
    Timer {
        interval: 1000
        repeat: true
        running: root.view.shown && !shot.live && shot.captureSource !== null
        onTriggered: shot.captureFrame()
    }

    IconImage {
        readonly property real size: Math.max(14, Math.min(34, Math.min(root.width, root.height) * 0.34))

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Math.min(Tokens.padding.small, root.height * 0.08)
        implicitSize: size
        source: Icons.getAppIcon(root.ipc?.class ?? "", "image-missing")
    }

    // Titre de la fenêtre survolée ou sélectionnée.
    StyledRect {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Tokens.padding.small
        implicitWidth: Math.min(root.width - Tokens.padding.small * 2, title.implicitWidth + Tokens.padding.medium * 2)
        implicitHeight: title.implicitHeight + Tokens.padding.extraSmall * 2
        radius: Tokens.rounding.full
        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.9)
        visible: opacity > 0 && root.width > 90
        opacity: (mouse.containsMouse || root.selected) && !root.dragging ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        StyledText {
            id: title

            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - Tokens.padding.medium * 2)
            text: root.toplevel.title ?? ""
            font: Tokens.font.label.small
            elide: Text.ElideRight
        }
    }

    // Contour de la fenêtre sélectionnée au clavier.
    Rectangle {
        anchors.fill: parent
        radius: Tokens.rounding.small
        color: "transparent"
        border.width: root.selected ? 2 : 0
        border.color: Colours.palette.m3primary
    }

    MouseArea {
        id: mouse

        property real startX
        property real startY
        property bool moved

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        onPressed: event => {
            // Coordonnées de scène : la miniature se déplace sous le pointeur pendant le glisser.
            const p = mapToItem(null, event.x, event.y);
            startX = p.x;
            startY = p.y;
            moved = false;
        }

        onPositionChanged: event => {
            if (!(pressedButtons & Qt.LeftButton))
                return;
            const p = mapToItem(null, event.x, event.y);
            const dx = p.x - startX;
            const dy = p.y - startY;
            if (!moved && Math.hypot(dx, dy) > 10) {
                moved = true;
                root.view.dragWindow = root.toplevel;
            }
            if (moved) {
                root.dragX = dx;
                root.dragY = dy;
                root.view.dropKey = root.view.cellAt(p.x, p.y);
            }
        }

        onReleased: event => {
            if (event.button === Qt.MiddleButton) {
                root.closing = true;
                closeTimer.restart();
                Qt.callLater(() => root.view.closeWindow(root.toplevel));
                return;
            }
            if (!moved) {
                root.view.focusWindow(root.toplevel);
                return;
            }
            const key = root.view.dropKey;
            root.view.dragWindow = null;
            root.view.dropKey = undefined;
            if (key !== undefined && key !== root.cell.wsKey) {
                root.dropped = true;
                dropTimer.restart();
                root.view.moveWindow(root.toplevel, key);
            }
            root.dragX = 0;
            root.dragY = 0;
        }

        onCanceled: {
            if (moved) {
                root.view.dragWindow = null;
                root.view.dropKey = undefined;
                root.dragX = 0;
                root.dragY = 0;
            }
        }
    }
}
