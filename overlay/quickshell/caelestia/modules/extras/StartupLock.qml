import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.lock

// Verrouillage à l'ouverture de la session : avec une connexion automatique, l'écran de
// verrouillage du shell sert d'écran de connexion (réglage `lock.atStartup` d'extras.json).
// Une seule fois par session Hyprland : un témoin dans le dossier d'exécution évite de
// reverrouiller quand le shell redémarre en cours de session.
Scope {
    id: root

    required property Lock lock
    // "" tant que rien n'est décidé, puis ce qui s'est passé (commande `startupLock status`).
    property string outcome

    readonly property string script: `
f="\${XDG_RUNTIME_DIR:-/tmp}/caelestia-session-\${HYPRLAND_INSTANCE_SIGNATURE:-default}"
[ -e "$f" ] && exit 1
: > "$f"
`

    function decide(): void {
        if (outcome !== "" || !Extras.loaded)
            return;
        outcome = "…";
        marker.exec(["sh", "-c", script]);
    }

    Component.onCompleted: decide()

    Connections {
        function onLoadedChanged(): void {
            root.decide();
        }

        target: Extras
    }

    Process {
        id: marker

        // Code 0 : premier démarrage du shell dans cette session.
        onExited: code => {
            if (code !== 0) {
                root.outcome = "shell redémarré en cours de session : pas de verrouillage";
            } else if (Extras.lock.atStartup) {
                root.lock.lock.locked = true;
                root.outcome = "session verrouillée à l'ouverture";
            } else {
                root.outcome = "ouverture de session : option désactivée";
            }
        }
    }

    IpcHandler {
        // Ce que le shell a décidé à son démarrage, et l'état du verrou.
        function status(): string {
            return `${root.outcome || "en attente des réglages"} · option ${Extras.lock.atStartup ? "activée" : "désactivée"} · écran ${root.lock.lock.locked ? "verrouillé" : "déverrouillé"}`;
        }

        target: "startupLock"
    }
}
