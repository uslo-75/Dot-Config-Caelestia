pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

// Mode « minuteur » du launcher : >timer 10, >timer 1h30 pâtes, >timer (durées prédéfinies et
// pomodoro). Avec un minuteur en cours : pause, reprise, arrêt.
ModeList {
    id: root

    required property var screenState
    required property string query
    property string keyword
    property var search

    readonly property string text: query.trim()
    // Première partie : la durée ; le reste : le nom du minuteur.
    readonly property real minutes: Timers.parse(text.split(/\s+/)[0] ?? "")
    readonly property string name: text.split(/\s+/).slice(1).join(" ")

    entries: {
        const out = [];
        if (minutes > 0)
            out.push({
                title: `Lancer un minuteur de ${Timers.describe(minutes)}`,
                subtitle: name || "Minuteur",
                icon: "timer",
                action: "start",
                minutes
            });
        if (Timers.active) {
            out.push({
                title: Timers.running ? "Mettre en pause" : "Reprendre",
                subtitle: `${Timers.label} · ${Timers.running ? "en cours" : "en pause"}`,
                icon: Timers.running ? "pause" : "play_arrow",
                action: "toggle"
            });
            out.push({
                title: "Arrêter le minuteur",
                subtitle: Timers.label,
                icon: "stop",
                action: "stop"
            });
        }
        if (!(minutes > 0)) {
            const p = Extras.timer.pomodoro;
            const others = Extras.timer.presets.map(m => ({
                        title: Timers.describe(m),
                        subtitle: "Minuteur",
                        icon: "timer",
                        action: "start",
                        minutes: m
                    }));
            others.push({
                title: "Pomodoro",
                subtitle: `${p.work} min de travail, ${p.shortBreak} min de pause, ${p.cycles} fois`,
                icon: "hourglass_top",
                action: "pomodoro"
            });
            const needle = text.toLowerCase();
            out.push(...others.filter(e => !needle || e.title.toLowerCase().includes(needle)));
        }
        return out;
    }
    emptyIcon: "timer"
    emptyTitle: "Durée illisible"
    emptyText: "Par exemple : 10, 25min, 90s, 1h30 ou 1:30"

    onActivated: entry => {
        if (entry.action === "start")
            Timers.start(entry.minutes, entry.minutes === minutes ? name : "");
        else if (entry.action === "pomodoro")
            Timers.startPomodoro();
        else if (entry.action === "toggle")
            Timers.toggle();
        else if (entry.action === "stop")
            Timers.stop();
        screenState.launcher = false;
    }
}
