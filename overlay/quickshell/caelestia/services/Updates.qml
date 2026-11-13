pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.utils

// Mises à jour du système : paquets des dépôts (checkupdates, de pacman-contrib), de l'AUR
// (yay ou paru) et Flatpak. Rien n'est installé d'ici : « tout mettre à jour » ouvre un
// terminal avec la commande habituelle. Prévient aussi quand le paquet du shell a été mis à
// jour alors que la copie modifiée (~/.config/quickshell/caelestia) le masque encore.
// Réglages : section `updates` d'extras.json.
Singleton {
    id: root

    property var repo: [] // { name, from, to }
    property var aur: []
    property var flatpak: [] // { name, to }
    property bool checking
    property real lastCheck // Dernière vérification réussie (ms).
    property string helper // "yay", "paru" ou "".
    property bool hasCheckupdates: true
    // Version installée du paquet du shell, et celle d'où vient la copie modifiée.
    property string shellPackage
    property string shellBuiltFrom
    property string repoPath // Dépôt des dotfiles, pour reconstruire la copie.
    property int notifiedCount
    property bool loaded
    property real now: Date.now()

    readonly property int count: repo.length + aur.length + flatpak.length

    // Demande d'ouvrir la page des mises à jour (les réglages ne peuvent pas être importés ici).
    signal openRequested
    readonly property bool shellStale: shellBuiltFrom !== "" && shellPackage !== "" && shellBuiltFrom !== shellPackage
    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || `${Paths.home}/.local/state`}/caelestia-portable`
    readonly property string command: {
        const custom = Extras.updates.command.trim();
        if (custom)
            return custom;
        const base = helper ? `${helper} -Syu` : "sudo pacman -Syu";
        return flatpak.length > 0 ? `${base}; flatpak update` : base;
    }
    // « à l'instant », « il y a 12 min », « il y a 3 h ».
    readonly property string lastCheckText: {
        if (!lastCheck)
            return "jamais vérifié";
        const min = Math.floor((now - lastCheck) / 60000);
        if (min < 1)
            return "vérifié à l'instant";
        if (min < 60)
            return `vérifié il y a ${min} min`;
        const h = Math.floor(min / 60);
        return h < 48 ? `vérifié il y a ${h} h` : `vérifié il y a ${Math.floor(h / 24)} jours`;
    }
    readonly property string summary: {
        const parts = [];
        if (repo.length)
            parts.push(`${repo.length} des dépôts`);
        if (aur.length)
            parts.push(`${aur.length} de l'AUR`);
        if (flatpak.length)
            parts.push(`${flatpak.length} Flatpak`);
        return parts.join(" · ");
    }

    function check(): void {
        if (checking)
            return;
        checking = true;
        checker.exec(["sh", "-c", checkScript, "sh", Extras.updates.aur ? "1" : "0", Extras.updates.flatpak ? "1" : "0", stateDir]);
    }

    // Ouvre un terminal avec la commande de mise à jour ; une nouvelle vérification suit sa fermeture.
    function upgrade(): void {
        runInTerminal(command);
    }

    // Reconstruit la copie modifiée du shell depuis le paquet installé (install.sh du dépôt).
    function rebuildShell(): void {
        if (repoPath)
            runInTerminal(`"${repoPath}/install.sh"`);
    }

    function runInTerminal(cmd: string): void {
        if (terminal.running)
            return;
        terminal.exec([...GlobalConfig.general.apps.terminal, "sh", "-c", `${cmd}; printf '\\nTerminé. Entrée pour fermer. '; read _`]);
    }

    function parsePackages(lines: var): var {
        const out = [];
        for (const line of lines) {
            const m = line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/);
            if (m)
                out.push({
                    name: m[1],
                    from: m[2],
                    to: m[3]
                });
        }
        return out;
    }

    function applyResult(text: string): void {
        const sections = {};
        let current = "";
        for (const line of text.split("\n")) {
            if (line.startsWith("@@")) {
                current = line.slice(2);
                sections[current] = [];
            } else if (current && line.trim() !== "") {
                sections[current].push(line);
            }
        }
        if (sections.done === undefined)
            return; // Sortie incomplète (vérification interrompue).

        repo = parsePackages(sections.repo ?? []);
        aur = parsePackages(sections.aur ?? []);
        flatpak = (sections.flatpak ?? []).map(l => {
            const [name, version] = l.split("\t");
            return {
                name: name.trim(),
                to: (version ?? "").trim()
            };
        }).filter(p => p.name !== "");
        helper = (sections.helper ?? [""])[0] ?? "";
        hasCheckupdates = (sections.tools ?? []).includes("checkupdates");
        shellPackage = (sections.shell ?? [""])[0] ?? "";
        shellBuiltFrom = (sections.built ?? [""])[0] ?? "";
        repoPath = (sections.repopath ?? [""])[0] ?? "";
        lastCheck = Date.now();
        now = lastCheck;

        if (Extras.updates.notify && count > notifiedCount)
            Quickshell.execDetached(["notify-send", "-a", "Mises à jour", `${count} mise${count > 1 ? "s" : ""} à jour disponible${count > 1 ? "s" : ""}`, summary]);
        notifiedCount = count;
        save();
    }

    function save(): void {
        if (loaded)
            stateFile.setText(JSON.stringify({
                repo,
                aur,
                flatpak,
                lastCheck,
                helper,
                hasCheckupdates,
                shellPackage,
                shellBuiltFrom,
                repoPath,
                notifiedCount
            }));
    }

    function load(text: string): void {
        let data = {};
        try {
            data = JSON.parse(text) ?? {};
        } catch (e) {
            data = {};
        }
        repo = Array.isArray(data.repo) ? data.repo : [];
        aur = Array.isArray(data.aur) ? data.aur : [];
        flatpak = Array.isArray(data.flatpak) ? data.flatpak : [];
        lastCheck = Number(data.lastCheck) || 0;
        helper = typeof data.helper === "string" ? data.helper : "";
        hasCheckupdates = data.hasCheckupdates ?? true;
        shellPackage = typeof data.shellPackage === "string" ? data.shellPackage : "";
        shellBuiltFrom = typeof data.shellBuiltFrom === "string" ? data.shellBuiltFrom : "";
        repoPath = typeof data.repoPath === "string" ? data.repoPath : "";
        notifiedCount = Number(data.notifiedCount) || 0;
        loaded = true;
    }

    // Vérification : une section par source, « @@done » à la fin.
    readonly property string checkScript: `
aur="$1"; flatpak="$2"; state="$3"
echo "@@repo"
if command -v checkupdates >/dev/null 2>&1; then checkupdates 2>/dev/null; else pacman -Qu 2>/dev/null | grep -v '\\[ignored\\]'; fi
echo "@@aur"
if [ "$aur" = 1 ]; then
    if command -v yay >/dev/null 2>&1; then yay -Qua 2>/dev/null
    elif command -v paru >/dev/null 2>&1; then paru -Qua 2>/dev/null; fi
fi
echo "@@flatpak"
if [ "$flatpak" = 1 ] && command -v flatpak >/dev/null 2>&1; then flatpak remote-ls --updates --columns=application,version 2>/dev/null; fi
echo "@@helper"
if command -v yay >/dev/null 2>&1; then echo yay; elif command -v paru >/dev/null 2>&1; then echo paru; fi
echo "@@tools"
command -v checkupdates >/dev/null 2>&1 && echo checkupdates
echo "@@shell"
pacman -Q caelestia-shell-git 2>/dev/null || pacman -Q caelestia-shell 2>/dev/null
echo "@@built"
cat "$state/qml-shell-version" 2>/dev/null
echo "@@repopath"
cat "$state/repo-path" 2>/dev/null
echo "@@done"
`

    Process {
        id: checker

        stdout: StdioCollector {
            onStreamFinished: {
                root.checking = false;
                root.applyResult(text);
            }
        }
    }

    // Terminal de mise à jour : à sa fermeture, l'état est vérifié de nouveau.
    Process {
        id: terminal

        onExited: root.check()
    }

    // Vérification périodique (et une première peu après le démarrage si la dernière est ancienne).
    Timer {
        interval: 60000
        repeat: true
        running: root.loaded && Extras.updates.enabled
        triggeredOnStart: false
        onTriggered: {
            root.now = Date.now();
            if (root.now - root.lastCheck >= Math.max(15, Extras.updates.interval) * 60000)
                root.check();
        }
    }

    FileView {
        id: stateFile

        path: `${Paths.state}/updates.json`
        printErrors: false
        atomicWrites: true
        onLoaded: root.load(text())
        onLoadFailed: root.load("{}")
    }

    IpcHandler {
        function check(): void {
            root.check();
        }

        function upgrade(): void {
            root.upgrade();
        }

        // Ouvre la page des mises à jour dans les réglages du shell.
        function open(): void {
            root.openRequested();
        }

        // Nombre de mises à jour, puis leur répartition.
        function status(): string {
            return `${root.count}\t${root.summary}\t${root.lastCheckText}${root.shellStale ? "\tcopie du shell à reconstruire" : ""}`;
        }

        function list(): string {
            return [...root.repo, ...root.aur].map(p => `${p.name} ${p.from} -> ${p.to}`).concat(root.flatpak.map(p => `${p.name} ${p.to}`)).join("\n");
        }

        target: "updates"
    }
}
