pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

// Contenu de la vue d'ensemble : bureau assombri, grille des espaces de travail avec leurs
// fenêtres en miniature, recherche et navigation au clavier.
Item {
    id: root

    required property var overview
    required property ShellScreen screen

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property var conf: Extras.overview
    // L'apparition démarre une fois la première image (encore transparente) affichée, pour
    // être jouée en entier ; la disparition dès la fermeture.
    property bool ready
    readonly property bool shown: overview.open && ready

    // ---- Espaces affichés ----

    readonly property int columns: Math.max(1, conf.columns)
    readonly property int rows: Math.max(1, conf.rows)
    readonly property int perPage: columns * rows
    readonly property int activeId: Math.max(1, monitor?.activeWorkspace?.id ?? 1)
    readonly property int firstId: Math.floor((activeId - 1) / perPage) * perPage + 1
    readonly property var ids: Array.from({
        length: perPage
    }, (_, i) => firstId + i)
    readonly property var specials: conf.showSpecial ? Hypr.workspaces.values.filter(w => w.name.startsWith("special:") && w.toplevels.values.length > 0).map(w => w.name).sort() : []
    readonly property var cellKeys: [...ids, ...specials]

    // ---- Fenêtres ----

    readonly property var windows: Hypr.toplevels.values.filter(t => !Hypr.isToplevelIgnored(t))
    // Fenêtres atteignables avec Tab : celles qui correspondent à la recherche, case par case.
    readonly property var navWindows: {
        const out = [];
        for (const key of cellKeys)
            out.push(...windowsFor(key).filter(t => matches(t)).sort((a, b) => (a.lastIpcObject.at[0] - b.lastIpcObject.at[0]) || (a.lastIpcObject.at[1] - b.lastIpcObject.at[1])));
        return out;
    }

    property string query
    property var selectedWs: activeId // Numéro, ou "special:nom"
    property HyprlandToplevel selectedWindow
    // Glisser-déposer : fenêtre tenue et case survolée.
    property HyprlandToplevel dragWindow
    property var dropKey

    // ---- Dimensions ----

    readonly property int gap: Tokens.spacing.medium
    readonly property int pad: Tokens.padding.extraLarge
    readonly property var area: usableArea(monitor)
    readonly property real specialScale: 0.6
    readonly property real cellW: {
        const byWidth = (Math.min(width * 0.92, 1800) - pad * 2 - (columns - 1) * gap) / columns;
        const specialRows = specials.length > 0 ? specialScale : 0;
        const availableH = height * 0.88 - pad * 2 - search.implicitHeight - hints.implicitHeight - gap * (rows + 1 + (specialRows > 0 ? 1 : 0));
        const byHeight = availableH / (rows + specialRows) * area.w / area.h;
        return Math.floor(Math.max(120, Math.min(byWidth, byHeight)));
    }
    readonly property real cellH: Math.round(cellW * area.h / area.w)

    function wsKey(ws: HyprlandWorkspace): var {
        return ws.name.startsWith("special:") ? ws.name : ws.id;
    }

    function windowsFor(key: var): var {
        return windows.filter(t => t.workspace && wsKey(t.workspace) === key);
    }

    // Zone d'un écran occupée par les fenêtres (hors barre et bordures), en coordonnées Hyprland.
    function usableArea(mon: HyprlandMonitor): var {
        const r = mon?.lastIpcObject?.reserved ?? [0, 0, 0, 0];
        const scale = mon?.scale || 1;
        return {
            x: (mon?.x ?? 0) + r[0],
            y: (mon?.y ?? 0) + r[1],
            w: Math.max(1, (mon?.width ?? 1920) / scale - r[0] - r[2]),
            h: Math.max(1, (mon?.height ?? 1080) / scale - r[1] - r[3])
        };
    }

    function normalise(text: string): string {
        return text.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
    }

    function matches(toplevel: HyprlandToplevel): bool {
        if (!query)
            return true;
        const q = normalise(query);
        const cls = toplevel.lastIpcObject?.class ?? "";
        return normalise(toplevel.title ?? "").includes(q) || normalise(cls).includes(q) || normalise(DesktopEntries.heuristicLookup(cls)?.name ?? "").includes(q);
    }

    function dispatch(lua: string, legacy: string): void {
        Hypr.dispatch(Hypr.usingLua ? lua : legacy);
    }

    function close(): void {
        overview.hide();
    }

    function focusWindow(toplevel: HyprlandToplevel): void {
        dispatch(`hl.dsp.focus({ window = "address:0x${toplevel.address}" })`, `focuswindow address:0x${toplevel.address}`);
        close();
    }

    function goTo(key: var): void {
        if (typeof key === "string") {
            if (monitor?.lastIpcObject?.specialWorkspace?.name !== key)
                Hypr.toggleSpecial(Hypr.trimWsName(key));
        } else {
            Hypr.focusWorkspace(key);
        }
        close();
    }

    function moveWindow(toplevel: HyprlandToplevel, key: var): void {
        dispatch(`hl.dsp.window.move({ window = "address:0x${toplevel.address}", workspace = "${key}", follow = false })`, `movetoworkspacesilent ${key},address:0x${toplevel.address}`);
    }

    function closeWindow(toplevel: HyprlandToplevel): void {
        if (selectedWindow === toplevel)
            selectedWindow = null;
        dispatch(`hl.dsp.window.close({ window = "address:0x${toplevel.address}" })`, `closewindow address:0x${toplevel.address}`);
    }

    // Case sous un point de la scène (pour le glisser-déposer).
    function cellAt(sceneX: real, sceneY: real): var {
        for (const container of [grid, specialRow]) {
            const p = container.mapFromItem(null, sceneX, sceneY);
            const item = container.childAt(p.x, p.y);
            if (item && item.wsKey !== undefined)
                return item.wsKey;
        }
        return undefined;
    }

    function cycleWindow(step: int): void {
        const list = navWindows;
        if (list.length === 0) {
            selectedWindow = null;
            return;
        }
        const i = list.indexOf(selectedWindow);
        selectedWindow = list[i < 0 ? (step > 0 ? 0 : list.length - 1) : (i + step + list.length) % list.length];
    }

    function moveSelection(dx: int, dy: int): void {
        selectedWindow = null;
        const i = cellKeys.indexOf(selectedWs);
        if (i < 0) {
            selectedWs = activeId;
            return;
        }
        if (i >= perPage) {
            // Rangée des espaces spéciaux.
            if (dy < 0)
                selectedWs = ids[Math.min(perPage - 1, (rows - 1) * columns + Math.min(columns - 1, i - perPage))];
            else if (dx !== 0)
                selectedWs = specials[Math.max(0, Math.min(specials.length - 1, i - perPage + dx))];
            return;
        }
        const col = i % columns;
        const row = Math.floor(i / columns);
        if (dy > 0 && row === rows - 1) {
            if (specials.length > 0)
                selectedWs = specials[Math.min(specials.length - 1, col)];
            return;
        }
        const nextCol = Math.max(0, Math.min(columns - 1, col + dx));
        const nextRow = Math.max(0, Math.min(rows - 1, row + dy));
        selectedWs = ids[nextRow * columns + nextCol];
    }

    function activate(): void {
        if (selectedWindow && navWindows.includes(selectedWindow))
            focusWindow(selectedWindow);
        else if (query && navWindows.length > 0)
            focusWindow(navWindows[0]);
        else
            goTo(selectedWs);
    }

    function handleKey(event: KeyEvent): bool {
        switch (event.key) {
        case Qt.Key_Escape:
            if (query)
                search.clear();
            else
                close();
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activate();
            return true;
        case Qt.Key_Tab:
            cycleWindow(event.modifiers & Qt.ShiftModifier ? -1 : 1);
            return true;
        case Qt.Key_Backtab:
            cycleWindow(-1);
            return true;
        case Qt.Key_Up:
            moveSelection(0, -1);
            return true;
        case Qt.Key_Down:
            moveSelection(0, 1);
            return true;
        case Qt.Key_Left:
            if (query)
                return false; // Déplace le curseur dans la recherche.
            moveSelection(-1, 0);
            return true;
        case Qt.Key_Right:
            if (query)
                return false;
            moveSelection(1, 0);
            return true;
        }
        return false;
    }

    onQueryChanged: selectedWindow = query && navWindows.length > 0 ? navWindows[0] : null
    onShownChanged: {
        if (shown) {
            search.clear();
            selectedWindow = null;
            selectedWs = activeId;
            search.forceActiveFocus();
        } else {
            dragWindow = null;
        }
    }

    Connections {
        function onFrameSwapped(): void {
            if (root.overview.open && !root.ready)
                root.ready = true;
        }

        target: root.Window.window
    }

    Connections {
        function onOpenChanged(): void {
            if (!root.overview.open)
                root.ready = false;
        }

        target: root.overview
    }

    // Bureau assombri (et flouté par Hyprland) ; un clic à côté referme.
    Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: root.shown ? Math.max(0, Math.min(1, root.conf.dim)) : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Item {
        id: panel

        anchors.centerIn: parent
        implicitWidth: layout.implicitWidth + root.pad * 2
        implicitHeight: layout.implicitHeight + root.pad * 2
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.95

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Elevation {
            anchors.fill: parent
            radius: surface.radius
            level: 3
        }

        StyledRect {
            id: surface

            anchors.fill: parent
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surface

            // Un clic sur le panneau ne referme pas la vue.
            MouseArea {
                anchors.fill: parent
            }
        }

        ColumnLayout {
            id: layout

            anchors.centerIn: parent
            spacing: root.gap

            SearchBar {
                id: search

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(grid.implicitWidth, 520)
                placeholderText: "Rechercher une fenêtre…"
                onTextChanged: root.query = text.trim()

                Keys.onPressed: event => {
                    if (root.handleKey(event))
                        event.accepted = true;
                }
            }

            Grid {
                id: grid

                Layout.alignment: Qt.AlignHCenter
                columns: root.columns
                spacing: root.gap

                Repeater {
                    model: root.ids

                    WorkspaceCell {
                        required property int modelData

                        view: root
                        wsKey: modelData
                        implicitWidth: root.cellW
                        implicitHeight: root.cellH
                    }
                }
            }

            Row {
                id: specialRow

                Layout.alignment: Qt.AlignHCenter
                visible: root.specials.length > 0
                spacing: root.gap

                Repeater {
                    model: root.specials

                    WorkspaceCell {
                        required property string modelData

                        view: root
                        wsKey: modelData
                        implicitWidth: Math.round(root.cellW * root.specialScale)
                        implicitHeight: Math.round(root.cellH * root.specialScale)
                    }
                }
            }

            StyledText {
                id: hints

                Layout.alignment: Qt.AlignHCenter
                text: "⏎ aller   ⇥ fenêtre suivante   ←↑↓→ espace   glisser pour déplacer   clic molette pour fermer   Échap"
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }
}
