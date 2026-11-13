pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Réglages des ajouts au shell (vue d'ensemble, modes du launcher…) : ~/.config/caelestia/extras.json.
// Le fichier est créé avec les valeurs par défaut au premier lancement, relu à chaud, et réécrit
// quand un réglage change depuis la page « Extras » des réglages du shell.
Singleton {
    id: root

    readonly property alias overview: adapter.overview
    readonly property alias files: adapter.files
    readonly property alias web: adapter.web
    readonly property alias timer: adapter.timer
    readonly property alias updates: adapter.updates
    readonly property alias capture: adapter.capture
    readonly property alias widgets: adapter.widgets
    readonly property alias lock: adapter.lock
    readonly property list<string> sections: ["overview", "files", "web", "timer", "updates", "capture", "widgets", "lock"]
    // Vrai une fois le fichier lu (ou créé) : les réglages valent alors ceux de l'utilisateur.
    property bool loaded

    // Page que la prochaine fenêtre de réglages doit afficher (-1 : celle par défaut) ; lue une
    // fois par la fenêtre à sa création (voir ExtraStatus.openSettings).
    property int requestedPage: -1

    function takeRequestedPage(): int {
        const page = requestedPage;
        requestedPage = -1;
        return page;
    }

    // Mode déplacement des widgets de bureau (non mémorisé).
    property bool editingWidgets

    // Modifie un widget de bureau : un tableau de l'adaptateur ne se change qu'en entier.
    function setWidget(index: int, changes: var): void {
        const items = adapter.widgets.items.map(i => Object.assign({}, i));
        if (!items[index])
            return;
        Object.assign(items[index], changes);
        adapter.widgets.items = items;
    }

    IpcHandler {
        // Bascule le mode déplacement des widgets de bureau.
        function edit(): void {
            root.editingWidgets = !root.editingWidgets;
        }

        // Affiche ou masque un type de widget ("clock", "weather", "system", "media", "calendar", "timer").
        function toggle(type: string): void {
            const index = adapter.widgets.items.findIndex(i => i.type === type);
            if (index >= 0)
                root.setWidget(index, {
                    enabled: !adapter.widgets.items[index].enabled
                });
        }

        target: "widgets"
    }

    // Un réglage changé depuis le shell est écrit après un court délai (plusieurs changements
    // d'affilée ne font qu'une écriture).
    Timer {
        id: writeTimer

        interval: 250
        onTriggered: view.writeAdapter()
    }

    FileView {
        id: view

        path: `${Paths.config}/extras.json`
        watchChanges: true
        printErrors: false
        // Tant qu'une écriture attend, le fichier n'est pas relu : il écraserait le changement.
        onFileChanged: {
            if (!writeTimer.running)
                reload();
        }
        onAdapterUpdated: writeTimer.restart()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
            root.loaded = true;
        }
        // Un fichier d'une version précédente est complété avec les nouvelles sections.
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (root.sections.some(k => data[k] === undefined))
                    writeAdapter();
            } catch (e) {
                // Fichier en cours d'édition : les valeurs par défaut restent en place.
            }
            root.loaded = true;
        }

        JsonAdapter {
            id: adapter

            property JsonObject overview: JsonObject {
                // Grille des espaces de travail : 2 x 5 = espaces 1 à 10, puis 11 à 20, etc.
                property int rows: 2
                property int columns: 5
                // Miniatures mises à jour en continu (sinon rafraîchies toutes les secondes).
                property bool livePreviews: true
                // Espaces spéciaux (scratchpads) occupés, sous la grille.
                property bool showSpecial: true
                // Assombrissement du bureau derrière la vue (0 à 1).
                property real dim: 0.5
            }

            // Mode « fichiers » du launcher (>files ou >f).
            property JsonObject files: JsonObject {
                // Dossiers parcourus ("~" : dossier personnel).
                property list<string> roots: ["~"]
                // Inclure les fichiers et dossiers cachés.
                property bool hidden: false
                property int maxResults: 50
            }

            // Mode « web » du launcher (>web, ou directement >clé).
            property JsonObject web: JsonObject {
                // key : mot à taper après « > » ; url : %s est remplacé par la recherche.
                property var engines: [
                    {
                        key: "g",
                        name: "Google",
                        icon: "search",
                        url: "https://www.google.com/search?q=%s"
                    },
                    {
                        key: "yt",
                        name: "YouTube",
                        icon: "smart_display",
                        url: "https://www.youtube.com/results?search_query=%s"
                    },
                    {
                        key: "gh",
                        name: "GitHub",
                        icon: "code",
                        url: "https://github.com/search?q=%s"
                    },
                    {
                        key: "w",
                        name: "Wikipédia",
                        icon: "menu_book",
                        url: "https://fr.wikipedia.org/w/index.php?search=%s"
                    },
                    {
                        key: "aw",
                        name: "ArchWiki",
                        icon: "terminal",
                        url: "https://wiki.archlinux.org/index.php?search=%s"
                    },
                    {
                        key: "aur",
                        name: "AUR",
                        icon: "deployed_code",
                        url: "https://aur.archlinux.org/packages?K=%s"
                    }
                ]
            }

            // Minuteur : témoin dans la barre, >timer dans le launcher.
            property JsonObject timer: JsonObject {
                // Durées proposées, en minutes.
                property var presets: [5, 10, 15, 25, 45]
                // Son à la fin d'un minuteur.
                property bool sound: true
                // Garder le témoin dans la barre même quand aucun minuteur ne tourne.
                property bool alwaysShow: false
                // Pomodoro : minutes de travail et de pause, grande pause après `cycles` séries.
                property JsonObject pomodoro: JsonObject {
                    property int work: 25
                    property int shortBreak: 5
                    property int longBreak: 15
                    property int cycles: 4
                }
            }

            // Mises à jour du système (dépôts, AUR, Flatpak).
            property JsonObject updates: JsonObject {
                // Vérification automatique.
                property bool enabled: true
                // Minutes entre deux vérifications (15 au moins).
                property int interval: 120
                property bool aur: true
                property bool flatpak: true
                // Témoin dans la barre quand des mises à jour attendent.
                property bool showInBar: true
                // Notification quand de nouvelles mises à jour arrivent.
                property bool notify: false
                // Commande lancée dans un terminal pour tout mettre à jour ("" : choisie d'après
                // les outils installés, par exemple « yay -Syu »).
                property string command: ""
            }

            // Outils de capture : texte d'une zone, QR code, pipette, GIF.
            property JsonObject capture: JsonObject {
                // Langues de la reconnaissance de texte, par exemple "fra+eng" ("" : toutes
                // celles installées pour tesseract).
                property string ocrLanguages: ""
                // GIF : images par seconde, largeur maximale et durée maximale.
                property int gifFps: 15
                property int gifWidth: 720
                property int gifMaxSeconds: 60
                // Dossier des GIF et des QR codes ("" : Images/Captures).
                property string directory: ""
            }

            // Écran de verrouillage.
            property JsonObject lock: JsonObject {
                // Verrouiller à l'ouverture de la session : avec une connexion automatique, l'écran
                // de verrouillage du shell sert d'écran de connexion.
                property bool atStartup: false
            }

            // Widgets de bureau, posés sur le fond d'écran (désactivés tant qu'on ne les demande pas).
            property JsonObject widgets: JsonObject {
                property bool enabled: false
                // Taille (1 = normale) et opacité du fond des widgets.
                property real scale: 1
                property real opacity: 0.6
                // type : "clock", "weather", "system", "media", "calendar" ou "timer".
                // screen : nom d'un écran, "" pour tous. x et y : position de 0 à 1.
                property var items: [
                    {
                        type: "clock",
                        enabled: false,
                        screen: "",
                        x: 0.5,
                        y: 0.12
                    },
                    {
                        type: "weather",
                        enabled: true,
                        screen: "",
                        x: 0.97,
                        y: 0.06
                    },
                    {
                        type: "system",
                        enabled: true,
                        screen: "",
                        x: 0.97,
                        y: 0.3
                    },
                    {
                        type: "media",
                        enabled: true,
                        screen: "",
                        x: 0.97,
                        y: 0.56
                    },
                    {
                        type: "calendar",
                        enabled: false,
                        screen: "",
                        x: 0.03,
                        y: 0.06
                    },
                    {
                        type: "timer",
                        enabled: false,
                        screen: "",
                        x: 0.03,
                        y: 0.5
                    }
                ]
            }
        }
    }
}
