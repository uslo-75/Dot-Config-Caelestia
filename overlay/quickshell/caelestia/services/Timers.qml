pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

// Minuteur et pomodoro : un seul compte à rebours à la fois, qui survit à un redémarrage du
// shell (l'heure de fin est gardée dans l'état). Témoin dans la barre, mode « >timer » du
// launcher, commande `caelestia shell timer …`. Réglages : section `timer` d'extras.json.
Singleton {
    id: root

    property real endAt // Heure de fin (ms) quand il tourne, sinon 0.
    property real pausedLeft // Reste (ms) quand il est en pause, sinon 0.
    property real total // Durée de la phase en cours (ms).
    property string label
    property string phase // "" : minuteur simple ; "work", "break", "long" : pomodoro.
    property int cycle // Numéro du pomodoro en cours.
    property real now: Date.now()
    property bool loaded

    readonly property bool running: endAt > 0
    readonly property bool paused: pausedLeft > 0
    readonly property bool active: running || paused
    readonly property real left: running ? Math.max(0, endAt - now) : pausedLeft
    readonly property real progress: total > 0 ? Math.max(0, Math.min(1, 1 - left / total)) : 0
    readonly property string text: format(left)
    // Pour la barre : minutes restantes, ou secondes sous la minute.
    readonly property string shortText: left >= 60000 ? String(Math.ceil(left / 60000)) : String(Math.ceil(left / 1000))

    function format(ms: real): string {
        const s = Math.ceil(ms / 1000);
        const h = Math.floor(s / 3600);
        const m = Math.floor(s / 60) % 60;
        const pad = n => String(n).padStart(2, "0");
        return h > 0 ? `${h}:${pad(m)}:${pad(s % 60)}` : `${m}:${pad(s % 60)}`;
    }

    // "10", "10m", "25min", "90s", "1h30", "1:30" (minutes:secondes), "2,5" -> minutes ; 0 si illisible.
    function parse(text: string): real {
        const t = text.trim().toLowerCase().replace(",", ".").replace(/\s+/g, "");
        if (!t)
            return 0;
        let m = t.match(/^(\d+):(\d{1,2})$/);
        if (m)
            return parseInt(m[1]) + parseInt(m[2]) / 60;
        if (/^\d+(\.\d+)?$/.test(t))
            return parseFloat(t); // Nombre seul : des minutes.
        // Avec des heures, le nombre qui suit sans unité est en minutes (« 1h30 »).
        m = t.match(/^(\d+(?:\.\d+)?)h(?:(\d+)(?:min|mn|m)?)?(?:(\d+)s)?$/);
        if (m)
            return parseFloat(m[1]) * 60 + parseFloat(m[2] ?? "0") + parseFloat(m[3] ?? "0") / 60;
        m = t.match(/^(?:(\d+(?:\.\d+)?)(?:min|mn|m))?(?:(\d+)s)?$/);
        if (!m || (m[1] === undefined && m[2] === undefined))
            return 0;
        return parseFloat(m[1] ?? "0") + parseFloat(m[2] ?? "0") / 60;
    }

    // « 10 min », « 1 h 30 », « 45 s ».
    function describe(minutes: real): string {
        const s = Math.round(minutes * 60);
        if (s < 60)
            return `${s} s`;
        const h = Math.floor(s / 3600);
        const m = Math.floor(s / 60) % 60;
        if (h > 0)
            return m > 0 ? `${h} h ${String(m).padStart(2, "0")}` : `${h} h`;
        return s % 60 > 0 ? `${m} min ${s % 60} s` : `${m} min`;
    }

    function begin(ms: real, name: string, ph: string): void {
        total = ms;
        now = Date.now();
        endAt = now + ms;
        pausedLeft = 0;
        label = name;
        phase = ph;
        save();
    }

    function start(minutes: real, name: string): void {
        if (!(minutes > 0))
            return;
        cycle = 0;
        begin(minutes * 60000, name || "Minuteur", "");
    }

    function startPomodoro(): void {
        cycle = 1;
        begin(Extras.timer.pomodoro.work * 60000, "Pomodoro : travail", "work");
    }

    function pause(): void {
        if (!running)
            return;
        pausedLeft = Math.max(1, endAt - Date.now());
        endAt = 0;
        save();
    }

    function resume(): void {
        if (!paused)
            return;
        now = Date.now();
        endAt = now + pausedLeft;
        pausedLeft = 0;
        save();
    }

    function toggle(): void {
        if (running)
            pause();
        else
            resume();
    }

    function add(minutes: real): void {
        if (!active || !(minutes > 0))
            return;
        if (running)
            endAt += minutes * 60000;
        else
            pausedLeft += minutes * 60000;
        total += minutes * 60000;
        save();
    }

    function stop(): void {
        endAt = 0;
        pausedLeft = 0;
        total = 0;
        label = "";
        phase = "";
        cycle = 0;
        save();
    }

    // Fin d'une phase : prévient, puis enchaîne (pomodoro) ou s'arrête.
    function finish(): void {
        const p = Extras.timer.pomodoro;
        if (phase === "work") {
            const long = cycle >= p.cycles;
            notify("Pause", long ? `${cycle} pomodoros faits : ${p.longBreak} min de grande pause.` : `Pomodoro ${cycle} sur ${p.cycles} fait : ${p.shortBreak} min de pause.`);
            begin((long ? p.longBreak : p.shortBreak) * 60000, long ? "Pomodoro : grande pause" : "Pomodoro : pause", long ? "long" : "break");
        } else if (phase === "break") {
            cycle++;
            notify("Au travail", `Pomodoro ${cycle} sur ${p.cycles} : ${p.work} min.`);
            begin(p.work * 60000, "Pomodoro : travail", "work");
        } else {
            notify(phase === "long" ? "Pomodoro terminé" : "Minuteur terminé", phase === "long" ? "La série est finie." : `${label} : ${describe(total / 60000)} écoulées.`);
            stop();
        }
    }

    function notify(title: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "Minuteur", "-u", "normal", title, body]);
        if (Extras.timer.sound)
            Quickshell.execDetached(["sh", "-c", 'f=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga; [ -f "$f" ] || exit 0; if command -v pw-play >/dev/null; then pw-play "$f"; else paplay "$f"; fi']);
    }

    function save(): void {
        if (loaded)
            stateFile.setText(JSON.stringify({
                endAt,
                pausedLeft,
                total,
                label,
                phase,
                cycle
            }));
    }

    function load(text: string): void {
        let data = {};
        try {
            data = JSON.parse(text) ?? {};
        } catch (e) {
            data = {};
        }
        endAt = Number(data.endAt) || 0;
        pausedLeft = Number(data.pausedLeft) || 0;
        total = Number(data.total) || 0;
        label = typeof data.label === "string" ? data.label : "";
        phase = typeof data.phase === "string" ? data.phase : "";
        cycle = Number(data.cycle) || 0;
        now = Date.now();
        loaded = true;
        // Terminé pendant que le shell était arrêté.
        if (endAt > 0 && endAt <= now) {
            notify("Minuteur terminé", `${label || "Minuteur"} : il s'est terminé pendant que le shell était arrêté.`);
            stop();
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: root.running
        onTriggered: {
            root.now = Date.now();
            if (root.running && root.now >= root.endAt)
                root.finish();
        }
    }

    FileView {
        id: stateFile

        path: `${Paths.state}/timer.json`
        printErrors: false
        atomicWrites: true
        onLoaded: root.load(text())
        onLoadFailed: root.load("{}")
    }

    IpcHandler {
        // Durée : "10", "25min", "90s", "1h30", "1:30"…
        function start(duration: string): string {
            const minutes = root.parse(duration);
            if (!(minutes > 0))
                return "durée illisible";
            root.start(minutes, "");
            return root.describe(minutes);
        }

        function pomodoro(): void {
            root.startPomodoro();
        }

        // Pause ou reprise.
        function toggle(): void {
            root.toggle();
        }

        function add(duration: string): void {
            root.add(root.parse(duration));
        }

        function stop(): void {
            root.stop();
        }

        function status(): string {
            return root.active ? `${root.label}\t${root.text}\t${root.running ? "en cours" : "en pause"}` : "aucun";
        }

        target: "timer"
    }
}
