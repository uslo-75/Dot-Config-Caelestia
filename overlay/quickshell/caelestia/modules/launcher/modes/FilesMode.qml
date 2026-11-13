pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.utils

// Mode « fichiers » du launcher (>files ou >f) : recherche par nom dans le dossier personnel
// avec ripgrep (ou find à défaut). Entrée ouvre, Maj+Entrée ouvre le dossier, Ctrl+Entrée
// copie le chemin.
ModeList {
    id: root

    required property var screenState
    required property string query
    property string keyword
    property var search

    readonly property var conf: Extras.files
    property var results: []
    property int requestId

    readonly property var icons: ({
            image: ["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "avif", "jxl", "ico"],
            movie: ["mp4", "mkv", "webm", "mov", "avi", "m4v"],
            music_note: ["mp3", "flac", "ogg", "opus", "wav", "m4a"],
            picture_as_pdf: ["pdf"],
            folder_zip: ["zip", "tar", "gz", "zst", "xz", "7z", "rar", "bz2"],
            code: ["qml", "js", "ts", "py", "lua", "sh", "c", "cpp", "h", "hpp", "rs", "go", "json", "toml", "yaml", "yml", "html", "css", "nix"],
            description: ["txt", "md", "odt", "doc", "docx", "rtf", "tex"],
            table_chart: ["csv", "ods", "xls", "xlsx"]
        })

    function iconFor(name: string): string {
        const ext = name.includes(".") ? name.slice(name.lastIndexOf(".") + 1).toLowerCase() : "";
        for (const [icon, exts] of Object.entries(icons))
            if (exts.includes(ext))
                return icon;
        return "draft";
    }

    function words(): var {
        return query.toLowerCase().split(/\s+/).filter(w => w);
    }

    function run(): void {
        const w = words();
        ++requestId;
        if (w.length === 0) {
            results = [];
            return;
        }
        // Le mot le plus long filtre côté ripgrep ; les autres sont vérifiés ici.
        const longest = w.slice().sort((a, b) => b.length - a.length)[0];
        const roots = conf.roots.map(r => r === "~" || r.startsWith("~/") ? Paths.home + r.slice(1) : r);
        proc.requestId = requestId;
        proc.exec(["sh", "-c", `q="$1"; hidden="$2"; shift 2
if command -v rg >/dev/null 2>&1; then
    if [ "$hidden" = 1 ]; then
        rg --files --hidden -g '!.git' -g '!.cache' -- "$@" 2>/dev/null
    else
        rg --files -- "$@" 2>/dev/null
    fi | rg -i -F -e "$q" | head -n 5000
else
    find "$@" -type f -not -path '*/.*' -ipath "*$q*" 2>/dev/null | head -n 5000
fi`, "sh", longest, conf.hidden ? "1" : "0", ...roots]);
    }

    function rank(lines: var): var {
        const w = words();
        const scored = [];
        for (const path of lines) {
            const lower = path.toLowerCase();
            if (!w.every(x => lower.includes(x)))
                continue;
            const name = path.slice(path.lastIndexOf("/") + 1);
            const lowerName = name.toLowerCase();
            // D'abord les noms de fichier qui contiennent tous les mots, les plus courts en tête.
            const inName = w.every(x => lowerName.includes(x)) ? 0 : 1;
            const starts = lowerName.startsWith(w[0]) ? 0 : 1;
            scored.push([inName, starts, name.length, path.length, path, name]);
        }
        scored.sort((a, b) => (a[0] - b[0]) || (a[1] - b[1]) || (a[2] - b[2]) || (a[3] - b[3]));
        return scored.slice(0, Math.max(1, conf.maxResults)).map(s => ({
                    title: s[5],
                    subtitle: Paths.shortenHome(s[4].slice(0, s[4].lastIndexOf("/"))),
                    icon: iconFor(s[5]),
                    path: s[4]
                }));
    }

    entries: results
    emptyIcon: query.trim() ? "search_off" : "folder_open"
    emptyTitle: query.trim() ? "Aucun fichier trouvé" : "Rechercher un fichier"
    emptyText: query.trim() ? "Essaie un autre nom" : "⏎ ouvrir   ⇧⏎ ouvrir le dossier   Ctrl+⏎ copier le chemin"

    onQueryChanged: debounce.restart()
    onActivated: (entry, modifiers) => {
        if (modifiers & Qt.ControlModifier)
            Clipboard.pasteText(entry.path, true);
        else if (modifiers & Qt.ShiftModifier)
            Quickshell.execDetached([...GlobalConfig.general.apps.explorer, entry.path.slice(0, entry.path.lastIndexOf("/"))]);
        else
            Quickshell.execDetached(["xdg-open", entry.path]);
        screenState.launcher = false;
    }

    Component.onCompleted: run()

    Timer {
        id: debounce

        interval: 110
        onTriggered: root.run()
    }

    Process {
        id: proc

        property int requestId

        stdout: StdioCollector {
            onStreamFinished: {
                if (proc.requestId === root.requestId)
                    root.results = root.rank(text.split("\n").filter(l => l));
            }
        }
    }
}
