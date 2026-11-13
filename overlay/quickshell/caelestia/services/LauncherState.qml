pragma Singleton

import Quickshell

// Mode demandé à l'ouverture du launcher ("" = applications, "wallpapers", "clipboard"),
// pour le launcher d'un écran précis : ceux des autres écrans ne changent pas de contenu.
Singleton {
    id: root

    // Dernière demande, remplacée d'un bloc et toujours lue d'un bloc : aucun launcher ne voit
    // un mode sans sa cible (sinon celui d'un autre écran chargerait le studio pour rien).
    property var request: ({
            mode: "",
            target: null // ScreenState visé (null : tous)
        })
    property int requestSerial: 0

    function open(mode: string, target: var): void {
        request = {
            mode,
            target: target ?? null
        };
        requestSerial++;
    }

    function clear(): void {
        request = {
            mode: "",
            target: null
        };
    }

    function concerns(screenState: var): bool {
        const r = request;
        return r.target === null || r.target === screenState;
    }

    function modeFor(screenState: var): string {
        const r = request;
        return r.target === null || r.target === screenState ? r.mode : "";
    }
}
