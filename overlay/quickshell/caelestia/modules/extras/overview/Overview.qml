pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components.containers
import qs.components.misc
import qs.services

// Vue d'ensemble des espaces de travail : une fenêtre plein écran sur l'écran actif, avec les
// fenêtres en miniature. Module autonome : le reste du shell ne le connaît que par la ligne
// `Overview {}` de shell.qml. Raccourci global « caelestia:overview », IPC « overview ».
Scope {
    id: root

    property bool open
    property ShellScreen screen: Screens.screens[0] ?? null

    function show(): void {
        const mon = Hypr.focusedMonitor;
        const target = Screens.screens.find(s => Hypr.monitorFor(s) === mon) ?? Screens.screens[0];
        if (!target)
            return;
        screen = target;
        hideTimer.stop();
        Hyprland.refreshToplevels(); // Positions et tailles à jour (Hyprland ne signale pas les redimensionnements).
        open = true;
        loader.activeAsync = true;
    }

    function hide(): void {
        if (!open)
            return;
        open = false;
        hideTimer.restart();
    }

    function toggle(): void {
        if (open)
            hide();
        else
            show();
    }

    // Flou et fondu de la couche par Hyprland, comme pour les panneaux du shell.
    function applyLayerRules(): void {
        const blur = Colours.transparency.enabled;
        if (Hypr.usingLua)
            Hypr.extras.batchMessage([`eval hl.layer_rule({ match = { namespace = "caelestia-overview" }, animation = "fade", blur = ${blur}, ignore_alpha = 0.05 })`]);
        else
            Hypr.extras.batchMessage(["keyword layerrule animation fade, match:namespace caelestia-overview", `keyword layerrule blur ${blur ? 1 : 0}, match:namespace caelestia-overview`, "keyword layerrule ignore_alpha 0.05, match:namespace caelestia-overview"]);
    }

    Component.onCompleted: applyLayerRules()

    Connections {
        function onConfigReloaded(): void {
            root.applyLayerRules();
        }

        // Au démarrage, le type de configuration (Lua ou non) n'est pas encore connu.
        function onUsingLuaChanged(): void {
            root.applyLayerRules();
        }

        target: Hypr
    }

    Connections {
        function onEnabledChanged(): void {
            root.applyLayerRules();
        }

        target: Colours.transparency
    }

    // La fenêtre reste affichée le temps de l'animation de fermeture.
    Timer {
        id: hideTimer

        interval: 300
    }

    // Créée peu après le démarrage puis gardée en mémoire, cachée : l'ouverture ne construit
    // rien et s'affiche dès la première image.
    Timer {
        interval: 2500
        running: true
        onTriggered: {
            if (root.screen)
                loader.activeAsync = true;
        }
    }

    LazyLoader {
        id: loader

        StyledWindow {
            id: win

            screen: root.screen
            name: "overview"
            visible: root.open || hideTimer.running
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            mask: root.open ? null : empty

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Region {
                id: empty
            }

            OverviewContent {
                anchors.fill: parent
                overview: root
                screen: win.screen
            }
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "overview"
        description: "Toggle the workspace overview"
        onPressed: root.toggle()
    }

    IpcHandler {
        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.show();
        }

        function close(): void {
            root.hide();
        }

        function isOpen(): string {
            return root.open ? "1" : "0";
        }

        target: "overview"
    }
}
