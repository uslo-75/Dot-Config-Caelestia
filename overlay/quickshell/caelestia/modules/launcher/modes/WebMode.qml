pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

// Mode « web » du launcher : >web liste les moteurs, >g, >yt, >gh… en choisit un directement.
// Entrée ouvre la recherche dans le navigateur par défaut. Les moteurs sont dans extras.json.
ModeList {
    id: root

    required property var screenState
    required property string query
    property string keyword
    property var search

    readonly property var engines: Extras.web.engines
    readonly property string text: query.trim()

    function host(url: string): string {
        const m = url.match(/^[a-z]+:\/\/([^\/]+)/i);
        return m ? m[1].replace(/^www\./, "") : url;
    }

    entries: engines.filter(e => !keyword || keyword === "web" || e.key === keyword).map(e => ({
                title: text ? `${e.name} : ${text}` : e.name,
                subtitle: host(e.url),
                icon: e.icon || "travel_explore",
                trailing: `${GlobalConfig.launcher.actionPrefix}${e.key}`,
                engine: e
            }))
    emptyIcon: "travel_explore"
    emptyTitle: "Aucun moteur de recherche"
    emptyText: "Ajoute-en dans ~/.config/caelestia/extras.json"

    onActivated: entry => {
        if (!text) {
            // Sans recherche : choisir ce moteur et attendre le texte.
            if (search)
                search.text = `${GlobalConfig.launcher.actionPrefix}${entry.engine.key} `;
            return;
        }
        Quickshell.execDetached(["xdg-open", entry.engine.url.replace("%s", encodeURIComponent(text))]);
        screenState.launcher = false;
    }
}
