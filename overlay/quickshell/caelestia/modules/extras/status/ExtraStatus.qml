pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.nexus

// Témoins des ajouts dans la barre (minuteur, mises à jour, GIF en cours) et ouverture des
// réglages du shell sur une page donnée.
Singleton {
    id: root

    // Témoins à afficher : seulement ceux qui ont quelque chose à dire.
    readonly property list<string> names: {
        const out = [];
        if (Capture.recording)
            out.push("gif");
        if (Timers.active || Extras.timer.alwaysShow)
            out.push("timer");
        if (Extras.updates.showInBar && (Updates.count > 0 || Updates.shellStale))
            out.push("updates");
        return out;
    }

    // Ouvre les réglages sur la page dont l'icône est donnée ("update", "widgets"…).
    function openSettings(icon: string): void {
        Extras.requestedPage = PageRegistry.pages.findIndex(p => p.icon === icon);
        WindowFactory.create();
    }

    Connections {
        function onOpenRequested(): void {
            root.openSettings("update");
        }

        target: Updates
    }

    IpcHandler {
        // Ouvre la page « Extras » des réglages du shell.
        function open(): void {
            root.openSettings("widgets");
        }

        target: "extras"
    }
}
