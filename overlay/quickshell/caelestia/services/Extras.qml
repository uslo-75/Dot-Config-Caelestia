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
        }
        // Un fichier d'une version précédente est complété avec les nouvelles sections.
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (["overview", "files", "web"].some(k => data[k] === undefined))
                    writeAdapter();
            } catch (e) {
                // Fichier en cours d'édition : les valeurs par défaut restent en place.
            }
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
        }
    }
}
