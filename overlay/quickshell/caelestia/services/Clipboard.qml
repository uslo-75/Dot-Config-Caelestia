pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

// Historique du presse-papiers (cliphist) avec épingles, aperçus d'images, heure et appli d'origine.
Singleton {
    id: root

    readonly property string binDir: `${Paths.home}/.local/bin`
    readonly property string pasteTool: `${binDir}/caelestia-clipboard-paste`
    readonly property string stateDir: `${Paths.state}/clipboard`
    readonly property string thumbDir: `${Paths.cache}/clipboard`
    readonly property string pinsPath: `${stateDir}/pins.json`
    readonly property string metaPath: `${stateDir}/meta.tsv`
    readonly property string dbPath: `${Quickshell.env("XDG_CACHE_HOME") || `${Paths.home}/.cache`}/cliphist/db`
    readonly property string pausedFlag: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/caelestia-clipboard-paused`

    property var entries: []
    property var pins: []
    property var meta: ({})
    property var thumbs: ({})
    property var decoded: ({})
    property string lastList
    property bool paused
    property bool loaded
    property int users

    readonly property var terminals: ["kitty", "foot", "alacritty", "wezterm", "org.wezfurlong.wezterm", "com.mitchellh.ghostty", "ghostty", "konsole", "org.kde.konsole", "gnome-terminal", "org.gnome.terminal", "org.gnome.console", "kgx", "xterm", "terminator", "tilix", "com.gexperts.tilix", "rio", "contour", "st", "blackbox", "com.raggesilver.blackbox"]

    // ---- Lecture ----

    function refresh(): void {
        listProc.exec(["cliphist", "list", "-preview-width", "400"]);
    }

    // Les vues ouvertes s'enregistrent pour recevoir les mises à jour en direct.
    function acquire(): void {
        users++;
        refresh();
    }

    function release(): void {
        users = Math.max(0, users - 1);
    }

    function collapse(text: string): string {
        return text.replace(/\s+/g, " ").trim();
    }

    function classify(id: string, preview: string): var {
        const entry = {
            id,
            preview,
            kind: "text",
            pinned: false
        };
        const bin = preview.match(/^\[\[ binary data (.+) (\w+) (\d+)x(\d+) \]\]$/);
        if (bin) {
            entry.kind = "image";
            entry.size = bin[1];
            entry.format = bin[2].toLowerCase();
            entry.width = Number(bin[3]);
            entry.height = Number(bin[4]);
            return entry;
        }
        if (/^\[\[ binary data .* \]\]$/.test(preview)) {
            entry.kind = "binary";
            return entry;
        }
        const t = preview.trim();
        if (/^(https?|ftp):\/\/\S+$/i.test(t))
            entry.kind = "link";
        else if (/^(#[0-9a-f]{3,4}|#[0-9a-f]{6}|#[0-9a-f]{8}|rgba?\([\d\s.,%/]+\)|hsla?\([\d\s.,%/deg]+\))$/i.test(t))
            entry.kind = "colour";
        else if (/^(file:\/\/)?(\/[^\s/]+)+\/?$/.test(t) || /^~\/\S*$/.test(t))
            entry.kind = "file";
        else if (/[{};]\s|=>|\bfunction\b|\bdef \w+\(|\bimport \w|#include|<\/?\w+[^>]*>|^\s*(\$ |sudo |git |cd |yay |pacman )/.test(t))
            entry.kind = "code";
        return entry;
    }

    // Aperçu tel que cliphist l'écrit (espaces réduits, 400 caractères puis « … »).
    function previewOf(text: string): string {
        const c = collapse(text ?? "");
        return c.length > 400 ? `${c.slice(0, 400)}…` : c;
    }

    function parse(text: string): var {
        const out = [];
        const pinned = new Set(pins.filter(p => p.kind !== "image").map(p => previewOf(p.text)));
        for (const line of text.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab <= 0)
                continue;
            const entry = classify(line.slice(0, tab), line.slice(tab + 1));
            entry.pinned = pinned.has(entry.preview);
            out.push(entry);
        }
        return out;
    }

    function timeOf(entry: var): real {
        if (!entry)
            return 0;
        if (entry.pinKey)
            return entry.time ?? 0;
        return meta[entry.id]?.time ?? 0;
    }

    function appOf(entry: var): string {
        if (!entry)
            return "";
        if (entry.pinKey)
            return entry.app ?? "";
        return meta[entry.id]?.app ?? "";
    }

    function relativeTime(seconds: real): string {
        if (!seconds)
            return "";
        const diff = Math.max(0, Date.now() / 1000 - seconds);
        if (diff < 45)
            return "à l'instant";
        if (diff < 3600)
            return `il y a ${Math.max(1, Math.round(diff / 60))} min`;
        const date = new Date(seconds * 1000);
        const now = new Date();
        const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() / 1000;
        const time = date.toLocaleTimeString(Qt.locale(), "HH:mm");
        if (seconds >= startOfToday)
            return diff < 6 * 3600 ? `il y a ${Math.round(diff / 3600)} h` : `aujourd'hui ${time}`;
        if (seconds >= startOfToday - 86400)
            return `hier ${time}`;
        return `${date.toLocaleDateString(Qt.locale(), "d MMM")} ${time}`;
    }

    function group(entry: var): string {
        if (entry?.pinKey)
            return "Épinglés";
        const seconds = timeOf(entry);
        if (!seconds)
            return "Plus ancien";
        const now = new Date();
        const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() / 1000;
        if (seconds >= startOfToday)
            return "Aujourd'hui";
        if (seconds >= startOfToday - 86400)
            return "Hier";
        if (seconds >= startOfToday - 6 * 86400)
            return "Cette semaine";
        return "Plus ancien";
    }

    function fullText(entry: var): string {
        if (!entry)
            return "";
        if (entry.pinKey)
            return entry.text ?? "";
        return decoded[entry.id] ?? "";
    }

    function needText(entry: var): void {
        if (!entry || entry.pinKey || entry.kind === "image" || entry.kind === "binary" || decoded[entry.id] !== undefined)
            return;
        // Un décodage à la fois (jamais interrompu) : le dernier demandé passe ensuite.
        if (decodeProc.running) {
            decodeProc.pendingId = entry.id;
            return;
        }
        decodeProc.requestId = entry.id;
        decodeProc.exec(["cliphist", "decode", entry.id]);
    }

    function imageFor(entry: var): string {
        if (!entry)
            return "";
        if (entry.pinKey)
            return entry.file ?? "";
        return thumbs[entry.id] ?? "";
    }

    function isTerminal(): bool {
        const cls = (Hypr.activeToplevel?.lastIpcObject?.class ?? "").toLowerCase();
        return terminals.includes(cls);
    }

    // ---- Actions ----

    function paste(entry: var, copyOnly: bool): void {
        if (!entry)
            return;
        const cmd = [pasteTool];
        if (copyOnly)
            cmd.push("--copy");
        else if (isTerminal())
            cmd.push("--terminal");

        if (entry.pinKey) {
            if (entry.kind === "image")
                cmd.push("--file", entry.file);
            else
                cmd.push("--text", entry.text ?? "");
        } else {
            cmd.push("--id", entry.id);
        }
        Quickshell.execDetached(cmd);
    }

    function remove(entry: var): void {
        if (!entry)
            return;
        if (entry.pinKey) {
            unpin(entry.pinKey);
            return;
        }
        entries = entries.filter(e => e.id !== entry.id);
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist delete", "sh", entry.id]);
    }

    function clear(): void {
        entries = [];
        lastList = "";
        thumbs = {};
        Quickshell.execDetached(["sh", "-c", "cliphist wipe; rm -rf -- \"$1\"", "sh", thumbDir]);
    }

    function setPaused(value: bool): void {
        paused = value;
        Quickshell.execDetached(value ? ["touch", pausedFlag] : ["rm", "-f", pausedFlag]);
    }

    function togglePin(entry: var): void {
        if (!entry)
            return;
        if (entry.pinKey) {
            unpin(entry.pinKey);
            return;
        }
        if (entry.pinned) {
            const match = pins.find(p => p.kind !== "image" && previewOf(p.text) === entry.preview);
            if (match)
                unpin(match.key);
            return;
        }
        if (pinProc.running)
            return;
        const key = `${Date.now().toString(36)}${Math.floor(Math.random() * 1e6).toString(36)}`;
        const pin = {
            key,
            pinKey: key,
            kind: entry.kind,
            app: appOf(entry),
            time: Date.now() / 1000
        };
        if (entry.kind === "image") {
            pin.file = `${stateDir}/pins/${key}.${entry.format || "png"}`;
            pin.width = entry.width;
            pin.height = entry.height;
            pin.size = entry.size;
            pin.format = entry.format;
            pinProc.pending = pin;
            pinProc.exec(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && cliphist decode \"$1\" > \"$2\"", "sh", entry.id, pin.file]);
        } else {
            pinProc.pending = pin;
            pinProc.exec(["cliphist", "decode", entry.id]);
        }
    }

    function unpin(key: string): void {
        const pin = pins.find(p => p.key === key);
        pins = pins.filter(p => p.key !== key);
        savePins();
        if (pin?.file)
            Quickshell.execDetached(["rm", "-f", pin.file]);
        entries = parse(lastList);
    }

    function savePins(): void {
        pinsFile.setText(JSON.stringify(pins.map(p => {
            const copy = Object.assign({}, p);
            delete copy.pinKey;
            return copy;
        }), null, 1));
    }

    // Décode les images de l'historique pour les miniatures (et supprime celles disparues).
    function syncThumbs(): void {
        const wanted = entries.filter(e => e.kind === "image").map(e => `${e.id}.${e.format}`);
        thumbProc.wanted = wanted;
        thumbProc.exec(["sh", "-c", `dir="$1"; shift; mkdir -p "$dir" || exit 0
for f in "$dir"/*; do [ -e "$f" ] || continue; keep=0; for w in "$@"; do [ "\${f##*/}" = "$w" ] && keep=1 && break; done; [ $keep = 1 ] || rm -f -- "$f"; done
for w in "$@"; do [ -s "$dir/$w" ] || { cliphist decode "\${w%%.*}" > "$dir/$w.tmp" && mv -f "$dir/$w.tmp" "$dir/$w"; }; done`, "sh", thumbDir, ...wanted]);
    }

    Process {
        id: listProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.lastList = text;
                root.entries = root.parse(text);
                root.loaded = true;
                root.syncThumbs();
            }
        }
    }

    Process {
        id: thumbProc

        property var wanted: []

        onExited: {
            const map = {};
            for (const w of wanted)
                map[w.split(".")[0]] = `${root.thumbDir}/${w}`;
            root.thumbs = map;
        }
    }

    Process {
        id: decodeProc

        property string requestId
        property string pendingId

        function startNext(): void {
            const id = pendingId;
            pendingId = "";
            if (id && root.decoded[id] === undefined) {
                requestId = id;
                exec(["cliphist", "decode", id]);
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const next = Object.assign({}, root.decoded);
                const keys = Object.keys(next);
                if (keys.length > 40)
                    delete next[keys[0]];
                next[decodeProc.requestId] = text;
                root.decoded = next;
                Qt.callLater(decodeProc.startNext);
            }
        }
    }

    Process {
        id: pinProc

        property var pending

        stdout: StdioCollector {
            onStreamFinished: {
                const pin = pinProc.pending;
                pinProc.pending = null;
                if (!pin)
                    return;
                if (pin.kind !== "image")
                    pin.text = text;
                root.pins = [pin, ...root.pins];
                root.savePins();
                root.entries = root.parse(root.lastList);
            }
        }
    }

    FileView {
        id: pinsFile

        path: root.pinsPath
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.pins = Array.isArray(data) ? data.map(p => Object.assign({}, p, {
                        pinKey: p.key
                    })) : [];
            } catch (e) {
                root.pins = [];
            }
            root.entries = root.parse(root.lastList);
        }
    }

    // Écrit par caelestia-clipboard-store après chaque copie : heure, appli, et signal de mise à jour.
    FileView {
        path: root.metaPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const map = {};
            for (const line of text().split("\n")) {
                const [id, time, app] = line.split("\t");
                if (id)
                    map[id] = {
                        time: Number(time) || 0,
                        app: app ?? ""
                    };
            }
            root.meta = map;
            if (root.users > 0)
                refreshTimer.restart();
        }
    }

    Timer {
        id: refreshTimer

        interval: 120
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        // État de la pause (le drapeau vit dans XDG_RUNTIME_DIR : il disparaît au redémarrage).
        pausedCheck.exec(["test", "-e", root.pausedFlag]);
    }

    Process {
        id: pausedCheck

        onExited: code => root.paused = code === 0
    }

    IpcHandler {
        function pause(): void {
            root.setPaused(true);
        }

        function resume(): void {
            root.setPaused(false);
        }

        function togglePause(): void {
            root.setPaused(!root.paused);
        }

        function isPaused(): bool {
            return root.paused;
        }

        target: "clipboard"
    }
}
