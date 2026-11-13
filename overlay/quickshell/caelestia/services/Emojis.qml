pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

// Emoji et symboles du mode « emoji » du launcher : la liste vient de `caelestia emoji`
// (emoji avec mots-clés en anglais, puis glyphes Nerd Font), les derniers utilisés sont
// gardés dans l'état du shell.
Singleton {
    id: root

    property var all: [] // { glyph, name, key }
    property var byGlyph: ({})
    property bool loaded
    readonly property alias recent: state.recent
    readonly property int limit: 260

    function load(): void {
        if (!loaded && !proc.running)
            proc.running = true;
    }

    function parse(text: string): void {
        const list = [];
        const map = {};
        for (const line of text.split("\n")) {
            const i = line.indexOf(" ");
            if (i <= 0)
                continue;
            const glyph = line.slice(0, i);
            const name = line.slice(i + 1).trim();
            // Les « indicateurs régionaux » seuls (A à Z) ne sont que des moitiés de drapeau.
            if (!name || map[glyph] || /^[\u{1F1E6}-\u{1F1FF}]$/u.test(glyph))
                continue;
            const entry = {
                glyph,
                name,
                key: name.toLowerCase().replace(/[-_]/g, " ")
            };
            map[glyph] = entry;
            list.push(entry);
        }
        byGlyph = map;
        all = list;
        loaded = true;
    }

    // Sans recherche : les derniers utilisés puis le début de la liste. Sinon tous les mots
    // doivent apparaître ; les noms qui commencent par la recherche passent devant.
    function search(query: string): var {
        const words = query.toLowerCase().split(/\s+/).filter(w => w);
        if (words.length === 0) {
            const used = recent.map(g => byGlyph[g]).filter(e => e);
            return [...used, ...all.filter(e => !recent.includes(e.glyph)).slice(0, limit - used.length)];
        }
        const first = [];
        const rest = [];
        for (const e of all) {
            if (!words.every(w => e.key.includes(w)))
                continue;
            (e.key.startsWith(words[0]) ? first : rest).push(e);
            if (first.length >= limit)
                break;
        }
        return [...first, ...rest].slice(0, limit);
    }

    function use(entry: var, copyOnly: bool): void {
        if (!entry)
            return;
        state.recent = [entry.glyph, ...recent.filter(g => g !== entry.glyph)].slice(0, 26);
        stateFile.writeAdapter();
        Clipboard.pasteText(entry.glyph, copyOnly);
    }

    Process {
        id: proc

        command: ["caelestia", "emoji"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    FileView {
        id: stateFile

        path: `${Paths.state}/emoji.json`
        printErrors: false

        JsonAdapter {
            id: state

            property list<string> recent: []
        }
    }
}
