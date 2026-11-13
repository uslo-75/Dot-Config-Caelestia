pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.State
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// Studio de fonds d'écran : carrousel 3D avec aperçu en direct sur le bureau,
// filtres, favoris, transitions, couleurs mémorisées par fond et diaporama.
Item {
    id: root

    required property var screenState
    required property var panels
    required property string query

    readonly property bool active: screenState.launcher
    property string overlay: "" // "", "transitions", "theme"
    property string lastPath: Wallpapers.actualCurrent
    property string lastQuery

    readonly property StudioCard currentCard: view.currentItem as StudioCard
    readonly property string currentPath: currentCard?.path ?? ""
    readonly property bool currentIsActual: currentPath !== "" && currentPath === Wallpapers.actualCurrent
    readonly property var currentTheme: {
        WallStudio.themes; // dépendance
        return WallStudio.themeFor(currentPath);
    }

    readonly property var filters: [
        {
            key: "all",
            name: "Tous",
            icon: "apps"
        },
        {
            key: "images",
            name: "Images",
            icon: "image"
        },
        {
            key: "videos",
            name: "Animés",
            icon: "animated_images"
        },
        {
            key: "favourites",
            name: "Favoris",
            icon: "star"
        }
    ]

    readonly property var entries: {
        WallStudio.favourites;
        WallStudio.items;
        const f = WallStudio.filter;
        return Wallpapers.query(query).filter(w => matches(w.path, f));
    }

    readonly property var counts: {
        WallStudio.favourites;
        WallStudio.items;
        const c = {
            all: 0,
            images: 0,
            videos: 0,
            favourites: 0
        };
        for (const w of Wallpapers.query(query)) {
            c.all++;
            if (WallStudio.isVideo(w.path))
                c.videos++;
            else
                c.images++;
            if (WallStudio.isFavourite(w.path))
                c.favourites++;
        }
        return c;
    }

    readonly property real availableWidth: {
        const screen = (QsWindow.window as QsWindow)?.screen;
        if (!screen)
            return 1200;
        const barMargins = Math.max(Config.border.thickness, panels.bar.implicitWidth);
        let outerMargins = 0;
        if ((screenState.utilities || screenState.sidebar) && panels.utilities.implicitWidth > outerMargins)
            outerMargins = panels.utilities.implicitWidth;
        return screen.width - Config.border.rounding * 4 - (barMargins + outerMargins) * 2 - Tokens.padding.large * 2;
    }
    readonly property int cardWidth: Math.round(Math.max(300, Math.min(Tokens.sizes.launcher.wallpaperWidth * 1.55, availableWidth * 0.28)))
    readonly property int cardHeight: Math.round(cardWidth * 9 / 16)

    function matches(path: string, f: string): bool {
        if (f === "images")
            return !WallStudio.isVideo(path);
        if (f === "videos")
            return WallStudio.isVideo(path);
        if (f === "favourites")
            return WallStudio.isFavourite(path);
        return true;
    }

    function restoreIndex(): void {
        const values = scriptModel.values;
        let idx;
        if (query && query !== lastQuery)
            idx = 0;
        else
            idx = values.findIndex(w => w.path === lastPath);
        if (idx < 0 && !query)
            idx = values.findIndex(w => w.path === Wallpapers.actualCurrent);
        lastQuery = query;
        view.currentIndex = Math.max(0, idx);
    }

    function applyCurrent(keepOpen: bool): void {
        const path = currentPath;
        if (!path)
            return;
        if (Colours.scheme === "dynamic" && path !== Wallpapers.actualCurrent)
            Wallpapers.previewColourLock = true;
        Wallpapers.setWallpaper(path);
        if (!keepOpen)
            screenState.launcher = false;
    }

    function cycleFilter(step: int): void {
        const keys = filters.map(f => f.key);
        const i = keys.indexOf(WallStudio.filter);
        WallStudio.setFilter(keys[(i + step + keys.length) % keys.length]);
    }

    function jump(step: int): void {
        if (view.count > 0)
            view.currentIndex = ((view.currentIndex + step) % view.count + view.count) % view.count;
    }

    function randomCard(): void {
        if (view.count < 2)
            return;
        let i = view.currentIndex;
        while (i === view.currentIndex)
            i = Math.floor(Math.random() * view.count);
        view.currentIndex = i;
    }

    function toggleOverlay(name: string): void {
        overlay = overlay === name ? "" : name;
    }

    function setTheme(mode: string, variant: string): void {
        if (!currentPath)
            return;
        WallStudio.setTheme(currentPath, mode, variant);
        Wallpapers.preview(currentPath); // couleurs de prévisualisation à jour
    }

    // Raccourcis clavier (appelé par la barre de recherche). Renvoie true si la touche est utilisée.
    function handleKey(event: KeyEvent): bool {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;

        if (event.key === Qt.Key_Escape && overlay) {
            overlay = "";
            return true;
        }

        if (ctrl) {
            switch (event.key) {
            case Qt.Key_D:
                WallStudio.toggleFavourite(currentPath);
                return true;
            case Qt.Key_R:
                randomCard();
                return true;
            case Qt.Key_T:
                toggleOverlay("transitions");
                return true;
            case Qt.Key_M:
                toggleOverlay("theme");
                return true;
            case Qt.Key_P:
                PersistentState.wallpaperPlaying = !PersistentState.wallpaperPlaying;
                return true;
            }
            return false;
        }

        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_Up:
            view.decrementCurrentIndex();
            return true;
        case Qt.Key_Right:
        case Qt.Key_Down:
            view.incrementCurrentIndex();
            return true;
        case Qt.Key_PageUp:
            jump(-5);
            return true;
        case Qt.Key_PageDown:
            jump(5);
            return true;
        case Qt.Key_Tab:
            cycleFilter(shift ? -1 : 1);
            return true;
        case Qt.Key_Backtab:
            cycleFilter(-1);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            overlay = "";
            applyCurrent(shift);
            return true;
        }
        return false;
    }

    implicitWidth: Math.min(availableWidth, Math.max(cardWidth * 3.4, 1440))
    implicitHeight: header.implicitHeight + Tokens.spacing.medium + carouselArea.height + Tokens.spacing.medium + info.implicitHeight

    onCurrentPathChanged: {
        if (currentPath)
            lastPath = currentPath;
        previewTimer.restart();
    }

    onActiveChanged: {
        if (!active) {
            overlay = "";
            previewTimer.stop();
            Wallpapers.stopPreview();
        }
    }

    Component.onDestruction: Wallpapers.stopPreview()

    // L'aperçu sur le bureau (transition + vidéo + couleurs) attend que la navigation se pose.
    Timer {
        id: previewTimer

        interval: 140
        onTriggered: {
            if (root.active && root.currentPath)
                Wallpapers.preview(root.currentPath);
        }
    }

    // ---- En-tête : filtres et réglages ----

    RowLayout {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.small

        Repeater {
            model: root.filters

            StudioChip {
                required property var modelData

                icon: modelData.icon
                text: modelData.name
                trailing: String(root.counts[modelData.key] ?? 0)
                checked: WallStudio.filter === modelData.key
                onClicked: WallStudio.setFilter(modelData.key)
            }
        }

        Item {
            Layout.fillWidth: true
        }

        StudioChip {
            icon: WallStudio.transitionIcon(WallStudio.transition)
            text: WallStudio.transitionName(WallStudio.transition)
            trailingIcon: "expand_more"
            checked: root.overlay === "transitions"
            onClicked: root.toggleOverlay("transitions")
        }

        IconButton {
            type: IconButton.Tonal
            icon: PersistentState.wallpaperPlaying ? "pause" : "play_arrow"
            onClicked: PersistentState.wallpaperPlaying = !PersistentState.wallpaperPlaying
        }

        IconButton {
            type: IconButton.Tonal
            icon: "shuffle"
            onClicked: WallStudio.shuffle(WallStudio.filter)
        }

        IconButton {
            id: slideshowButton

            type: IconButton.Tonal
            checked: WallStudio.slideshowMinutes > 0
            icon: "slideshow"
            onClicked: slideshowMenu.expanded = !slideshowMenu.expanded
        }

        IconButton {
            id: qualityButton

            type: IconButton.Tonal
            icon: WallStudio.videoQuality === "source" ? "4k" : "hd"
            onClicked: qualityMenu.expanded = !qualityMenu.expanded
        }
    }

    Menu {
        id: slideshowMenu

        attachTo: slideshowButton
        attachSideY: Menu.Bottom
        thisSideY: Menu.Top
        marginY: Tokens.spacing.small
        active: items.find(i => i.value === WallStudio.slideshowMinutes) ?? items[0]
        items: [
            MenuItem {
                text: "Diaporama désactivé"
                icon: "timer_off"
                value: 0
                onClicked: WallStudio.setSlideshow(0, "")
            },
            MenuItem {
                text: "Toutes les 5 minutes"
                icon: "timer"
                value: 5
                onClicked: WallStudio.setSlideshow(5, WallStudio.filter)
            },
            MenuItem {
                text: "Toutes les 15 minutes"
                icon: "timer"
                value: 15
                onClicked: WallStudio.setSlideshow(15, WallStudio.filter)
            },
            MenuItem {
                text: "Toutes les 30 minutes"
                icon: "timer"
                value: 30
                onClicked: WallStudio.setSlideshow(30, WallStudio.filter)
            },
            MenuItem {
                text: "Toutes les heures"
                icon: "schedule"
                value: 60
                onClicked: WallStudio.setSlideshow(60, WallStudio.filter)
            }
        ]
    }

    Menu {
        id: qualityMenu

        attachTo: qualityButton
        attachSideY: Menu.Bottom
        thisSideY: Menu.Top
        marginY: Tokens.spacing.small
        active: items.find(i => i.value === WallStudio.videoQuality) ?? items[0]
        items: [
            MenuItem {
                text: `Vidéo adaptée à l'écran (${WallStudio.targetHeight}p)`
                icon: "hd"
                value: "auto"
                onClicked: WallStudio.setVideoQuality("auto")
            },
            MenuItem {
                text: "Vidéo source (4K, plus gourmand)"
                icon: "4k"
                value: "source"
                onClicked: WallStudio.setVideoQuality("source")
            }
        ]
    }

    // ---- Carrousel ----

    Item {
        id: carouselArea

        anchors.top: header.bottom
        anchors.topMargin: Tokens.spacing.medium
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.cardHeight + Tokens.padding.large * 2

        // Halo coloré derrière la carte sélectionnée.
        Image {
            id: glowSource

            anchors.centerIn: parent
            width: root.cardWidth * 1.25
            height: root.cardHeight * 1.25
            source: root.currentPath ? WallStudio.fileUrl(WallStudio.posterFor(root.currentPath)) : ""
            sourceSize: Qt.size(96, 54)
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            visible: false
        }

        MultiEffect {
            anchors.fill: glowSource
            source: glowSource
            blurEnabled: true
            blur: 1
            blurMax: 64
            autoPaddingEnabled: true
            opacity: glowSource.status === Image.Ready && root.overlay === "" ? 0.6 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.SlowEffects
                }
            }
        }

        PathView {
            id: view

            readonly property int visibleCount: {
                const max = Math.max(1, Math.floor((width - root.cardWidth) / (root.cardWidth * 0.32)) + 1);
                let n = Math.min(count, max, 11);
                if (n > 1 && n % 2 === 0)
                    n--;
                return Math.max(1, n);
            }
            readonly property real step: Math.min(0.25, 1 / Math.max(1, visibleCount))

            anchors.fill: parent
            opacity: root.overlay === "" ? 1 : 0.15
            enabled: root.overlay === ""

            model: ScriptModel {
                id: scriptModel

                values: root.entries
                onValuesChanged: root.restoreIndex()
            }

            pathItemCount: visibleCount
            cacheItemCount: 4
            snapMode: PathView.SnapToItem
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: Tokens.anim.durations.normal

            Component.onCompleted: root.restoreIndex()

            delegate: StudioCard {
                cardWidth: root.cardWidth
                cardHeight: root.cardHeight
                onActivated: root.applyCurrent(false)
            }

            path: Path {
                startX: 0
                startY: view.height / 2

                PathAttribute {
                    name: "itemScale"
                    value: 0.56
                }
                PathAttribute {
                    name: "itemAngle"
                    value: 52
                }
                PathAttribute {
                    name: "itemZ"
                    value: 0
                }
                PathAttribute {
                    name: "itemDim"
                    value: 1
                }

                PathLine {
                    x: view.width / 2 - root.cardWidth * 0.66
                    y: view.height / 2
                }
                PathPercent {
                    value: 0.5 - view.step
                }
                PathAttribute {
                    name: "itemScale"
                    value: 0.74
                }
                PathAttribute {
                    name: "itemAngle"
                    value: 38
                }
                PathAttribute {
                    name: "itemZ"
                    value: 50
                }
                PathAttribute {
                    name: "itemDim"
                    value: 0.45
                }

                PathLine {
                    x: view.width / 2
                    y: view.height / 2
                }
                PathPercent {
                    value: 0.5
                }
                PathAttribute {
                    name: "itemScale"
                    value: 1
                }
                PathAttribute {
                    name: "itemAngle"
                    value: 0
                }
                PathAttribute {
                    name: "itemZ"
                    value: 100
                }
                PathAttribute {
                    name: "itemDim"
                    value: 0
                }

                PathLine {
                    x: view.width / 2 + root.cardWidth * 0.66
                    y: view.height / 2
                }
                PathPercent {
                    value: 0.5 + view.step
                }
                PathAttribute {
                    name: "itemScale"
                    value: 0.74
                }
                PathAttribute {
                    name: "itemAngle"
                    value: -38
                }
                PathAttribute {
                    name: "itemZ"
                    value: 50
                }
                PathAttribute {
                    name: "itemDim"
                    value: 0.45
                }

                PathLine {
                    x: view.width
                    y: view.height / 2
                }
                PathPercent {
                    value: 1
                }
                PathAttribute {
                    name: "itemScale"
                    value: 0.56
                }
                PathAttribute {
                    name: "itemAngle"
                    value: -52
                }
                PathAttribute {
                    name: "itemZ"
                    value: 0
                }
                PathAttribute {
                    name: "itemDim"
                    value: 1
                }
            }

            CustomMouseArea {
                function onWheel(event: WheelEvent): void {
                    if (event.angleDelta.y > 0 || event.angleDelta.x > 0)
                        view.decrementCurrentIndex();
                    else
                        view.incrementCurrentIndex();
                }

                anchors.fill: parent
                acceptedButtons: Qt.NoButton
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // Aucun résultat
        Column {
            anchors.centerIn: parent
            spacing: Tokens.spacing.small
            opacity: view.count === 0 ? 1 : 0
            visible: opacity > 0

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: WallStudio.filter === "favourites" ? "star" : "wallpaper_slideshow"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.extraLarge
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: WallStudio.filter === "favourites" && !root.query ? "Aucun favori pour l'instant" : "Aucun fond trouvé"
                font: Tokens.font.title.small
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (Wallpapers.list.length === 0)
                        return `Ajoute des images ou des vidéos dans ${Paths.shortenHome(Paths.wallsdir)}`;
                    if (WallStudio.filter === "favourites" && !root.query)
                        return "Ctrl+D ou l'étoile pour ajouter le fond sélectionné";
                    return "Essaie une autre recherche ou un autre filtre";
                }
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        TransitionPicker {
            anchors.fill: parent
            anchors.bottomMargin: -info.implicitHeight - Tokens.spacing.medium
            z: 200
            shown: root.overlay === "transitions"
            fromSource: WallStudio.fileUrl(Wallpapers.stillFor(Wallpapers.actualCurrent))
            toSource: root.currentPath ? WallStudio.fileUrl(WallStudio.posterFor(root.currentPath)) : ""
            onClosed: root.overlay = ""
        }

        ThemePicker {
            anchors.fill: parent
            anchors.bottomMargin: -info.implicitHeight - Tokens.spacing.medium
            z: 200
            shown: root.overlay === "theme"
            path: root.currentPath
            theme: root.currentTheme
            onPicked: (mode, variant) => root.setTheme(mode, variant)
            onClosed: root.overlay = ""
        }
    }

    // ---- Informations et couleurs du fond sélectionné ----

    RowLayout {
        id: info

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Tokens.spacing.medium
        opacity: root.overlay === "" && view.count > 0 ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        IconButton {
            type: IconButton.Text
            icon: "star"
            isToggle: true
            checked: WallStudio.favourites.includes(root.currentPath)
            onClicked: WallStudio.toggleFavourite(root.currentPath)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.currentPath ? WallStudio.displayName(root.currentPath) : ""
                font: Tokens.font.title.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    if (!root.currentPath)
                        return "";
                    const parts = WallStudio.details(root.currentPath);
                    if (root.currentIsActual)
                        parts.push("fond actuel");
                    return parts.join("  ·  ");
                }
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: "⏎ appliquer   ⇧⏎ sans fermer   ⇥ filtre   Ctrl+D favori   Ctrl+R hasard   Ctrl+T transition   Ctrl+M couleurs   Ctrl+P pause"
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        StudioChip {
            icon: "palette"
            text: {
                const t = root.currentTheme;
                if (t.mode === "auto" && t.variant === "auto")
                    return "Couleurs auto";
                const mode = WallStudio.modes.find(m => m.key === t.mode)?.name ?? "Auto";
                const variant = WallStudio.variants.find(v => v.key === t.variant)?.name ?? "Auto";
                return `${mode} · ${variant}`;
            }
            trailingIcon: "expand_less"
            checked: root.overlay === "theme"
            onClicked: root.toggleOverlay("theme")
        }

        IconTextButton {
            type: TextButton.Filled
            icon: root.currentIsActual ? "check_circle" : "wallpaper"
            text: root.currentIsActual ? "Fond actuel" : "Appliquer"
            disabled: root.currentIsActual || !root.currentPath
            onClicked: root.applyCurrent(false)
        }
    }
}
