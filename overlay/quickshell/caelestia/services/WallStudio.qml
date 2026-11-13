pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.State
import qs.services
import qs.utils

// Studio de fonds d'écran : favoris, thème mémorisé par fond, transitions, diaporama et
// cache vidéo (copies à la taille de l'écran, aperçus de survol) préparé par caelestia-wallpaper-cache.
Singleton {
    id: root

    readonly property string binDir: `${Paths.home}/.local/bin`
    readonly property string cacheTool: `${binDir}/caelestia-wallpaper-cache`
    readonly property string applyTool: `${binDir}/caelestia-wallpaper-apply`
    readonly property string indexPath: `${Quickshell.env("XDG_CACHE_HOME") || `${Paths.home}/.cache`}/caelestia/wallpaper-video/index.json`
    readonly property string statePath: `${Paths.state}/wallstudio.json`

    // Index du cache : chemin -> { kind, width, height, fps, duration, size, playable, poster,
    // strip, stripFrames, stripCols, stripFps }
    property var items: ({})
    property string videoQuality: "auto"
    property int targetHeight: 1080

    // État persistant
    property var favourites: []
    property var themes: ({})
    property string transition: "random"
    property int slideshowMinutes: 0
    property string slideshowPool: "all"
    property string filter: "all"
    property bool stateLoaded

    // Transition du prochain changement de fond (clé de Caelestia.Shaders, "" = celle de la config)
    property string activeTransition

    readonly property var transitionInfo: ({
            chromaticBloom: ["Éclat chromatique", "flare"],
            colourDistance: ["Distance de couleur", "palette"],
            crossfade: ["Fondu enchaîné", "gradient"],
            crosshatch: ["Hachures", "grid_4x4"],
            crosswarp: ["Distorsion croisée", "swap_horiz"],
            directional: ["Glissement", "arrow_forward"],
            directionalWipe: ["Balayage", "swipe_right"],
            fadeColour: ["Fondu coloré", "contrast"],
            glitch: ["Glitch", "broken_image"],
            glitchDisplace: ["Glitch décalé", "splitscreen"],
            heatMelt: ["Fonte", "local_fire_department"],
            inkSplash: ["Éclaboussure d'encre", "format_paint"],
            inkwellDrop: ["Goutte d'encre", "water_drop"],
            iris: ["Iris", "camera"],
            morph: ["Morphose", "blur_on"],
            parametricGlitch: ["Glitch paramétrique", "tune"],
            perlin: ["Dissolution", "grain"],
            pixelate: ["Pixellisation", "grid_on"],
            pixelfadeWave: ["Vague de pixels", "waves"],
            plasmaFlow: ["Plasma", "bubble_chart"],
            polkaDotsCurtain: ["Rideau de pois", "blur_circular"],
            puzzleRight: ["Puzzle", "extension"],
            randomSquares: ["Carrés aléatoires", "auto_awesome_mosaic"],
            smoke: ["Fumée", "cloud"],
            softWarpFade: ["Fondu ondulé", "water"],
            voronoiShatter: ["Éclats de verre", "diamond"],
            zoomBlurPull: ["Zoom flou", "zoom_in_map"]
        })
    readonly property list<string> transitions: Object.keys(transitionInfo).sort((a, b) => transitionName(a).localeCompare(transitionName(b)))
    // Transitions tirées au sort en mode aléatoire : les plus douces sur des fonds animés.
    readonly property list<string> randomPool: ["iris", "inkSplash", "smoke", "voronoiShatter", "plasmaFlow", "softWarpFade", "chromaticBloom", "morph", "zoomBlurPull", "pixelfadeWave", "crosswarp", "inkwellDrop", "heatMelt", "polkaDotsCurtain", "directionalWipe", "perlin"]

    readonly property var modes: [
        {
            key: "auto",
            name: "Auto",
            icon: "hdr_auto"
        },
        {
            key: "dark",
            name: "Sombre",
            icon: "dark_mode"
        },
        {
            key: "light",
            name: "Clair",
            icon: "light_mode"
        }
    ]
    readonly property var variants: [
        {
            key: "auto",
            name: "Auto"
        },
        {
            key: "tonalspot",
            name: "Tonal"
        },
        {
            key: "vibrant",
            name: "Vibrant"
        },
        {
            key: "expressive",
            name: "Expressif"
        },
        {
            key: "fidelity",
            name: "Fidèle"
        },
        {
            key: "content",
            name: "Contenu"
        },
        {
            key: "fruitsalad",
            name: "Salade de fruits"
        },
        {
            key: "rainbow",
            name: "Arc-en-ciel"
        },
        {
            key: "neutral",
            name: "Neutre"
        },
        {
            key: "monochrome",
            name: "Monochrome"
        }
    ]

    // ---- Métadonnées ----

    function fileUrl(path: string): string {
        if (!path)
            return "";
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function entry(path: string): var {
        return items[path] ?? null;
    }

    function isVideo(path: string): bool {
        const e = items[path];
        if (e)
            return e.kind === "video";
        return /\.(mp4|webm|mkv|mov|avi|m4v)$/i.test(path);
    }

    function playableFor(path: string): string {
        return items[path]?.playable ?? path;
    }

    function posterFor(path: string): string {
        if (!isVideo(path))
            return path;
        return items[path]?.poster ?? "";
    }

    function displayName(path: string): string {
        let name = path.slice(path.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "");
        name = name.replace(/(^|[-_ .])(moewalls|wallpaperwaves|mylivewallpapers|wallpaperengine|motionbgs|wallhaven)([-_ .]?com)?(?=$|[-_ .])/gi, " ");
        name = name.replace(/\b\d{3,4}x\d{3,4}\b|\b[48]k\b|\(\d+\)/gi, " ");
        name = name.replace(/[-_.]+/g, " ").replace(/\s+/g, " ").trim();
        if (!name)
            return path.slice(path.lastIndexOf("/") + 1);
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    function formatDuration(seconds: real): string {
        if (seconds < 60)
            return `${Math.round(seconds)} s`;
        const m = Math.floor(seconds / 60);
        const s = Math.round(seconds % 60);
        return `${m} min ${s < 10 ? "0" : ""}${s}`;
    }

    function formatSize(bytes: real): string {
        if (bytes >= 1024 ** 3)
            return `${(bytes / 1024 ** 3).toFixed(1).replace(".", ",")} Go`;
        if (bytes >= 1024 ** 2)
            return `${Math.round(bytes / 1024 ** 2)} Mo`;
        return `${Math.max(1, Math.round(bytes / 1024))} Ko`;
    }

    function details(path: string): var {
        const e = items[path];
        if (!e)
            return [isVideo(path) ? "Vidéo" : "Image"];
        const out = [e.kind === "video" ? "Vidéo" : "Image"];
        if (e.width && e.height)
            out.push(e.height >= 2160 ? `4K · ${e.width}×${e.height}` : `${e.width}×${e.height}`);
        if (e.fps)
            out.push(`${Math.round(e.fps)} i/s`);
        if (e.duration)
            out.push(formatDuration(e.duration));
        if (e.size)
            out.push(formatSize(e.size));
        return out;
    }

    // ---- Favoris ----

    function isFavourite(path: string): bool {
        return favourites.includes(path);
    }

    function toggleFavourite(path: string): void {
        if (!path)
            return;
        favourites = isFavourite(path) ? favourites.filter(p => p !== path) : [...favourites, path];
        save();
    }

    // ---- Thème mémorisé par fond ----

    function themeFor(path: string): var {
        return themes[path] ?? {
            mode: "auto",
            variant: "auto"
        };
    }

    function hasTheme(path: string): bool {
        const t = themes[path];
        return !!t && (t.mode !== "auto" || t.variant !== "auto");
    }

    // Change le mode ou la variante mémorisés pour `path` et applique ce fond avec.
    function setTheme(path: string, mode: string, variant: string): void {
        if (!path)
            return;
        const next = Object.assign({}, themes);
        if (mode === "auto" && variant === "auto")
            delete next[path];
        else
            next[path] = {
                mode,
                variant
            };
        themes = next;
        save();
        apply(path, true);
    }

    // ---- Transitions ----

    function transitionName(key: string): string {
        if (key === "random")
            return "Aléatoire";
        if (key === "config" || !key)
            return "Par défaut";
        return transitionInfo[key]?.[0] ?? key;
    }

    function transitionIcon(key: string): string {
        if (key === "random")
            return "casino";
        if (key === "config" || !key)
            return "gradient";
        return transitionInfo[key]?.[1] ?? "auto_awesome";
    }

    function pickRandom(): string {
        const pool = randomPool.filter(t => t !== activeTransition);
        return pool[Math.floor(Math.random() * pool.length)] ?? "crossfade";
    }

    function setTransition(key: string): void {
        transition = key;
        activeTransition = key === "random" ? pickRandom() : (key === "config" ? "" : key);
        save();
    }

    // Appelé juste avant chaque changement de fond (aperçu compris).
    function nextTransition(): void {
        if (transition === "random")
            activeTransition = pickRandom();
    }

    // ---- Application ----

    function apply(path: string, force: bool): void {
        if (!path)
            return;
        if (!force && path === Wallpapers.actualCurrent)
            return;

        const theme = themeFor(path);
        const cmd = [applyTool, path, "--mode", theme.mode, "--variant", theme.variant];
        if (!GlobalConfig.services.smartScheme)
            cmd.push("--no-smart");
        if (path !== Wallpapers.current)
            nextTransition();
        Wallpapers.actualCurrent = path;
        Quickshell.execDetached(cmd);
    }

    // Identifie un aperçu de couleurs : fond + thème mémorisé + réglage « intelligent ».
    function previewKey(path: string): string {
        const theme = themeFor(path);
        return `${path}|${theme.mode}|${theme.variant}|${GlobalConfig.services.smartScheme ? 1 : 0}`;
    }

    // Commande de prévisualisation des couleurs (respecte le thème mémorisé du fond).
    function previewCommand(path: string): var {
        const theme = themeFor(path);
        const cmd = [applyTool, "--print", "--tag", previewKey(path), path, "--mode", theme.mode, "--variant", theme.variant];
        if (!GlobalConfig.services.smartScheme)
            cmd.push("--no-smart");
        return cmd;
    }

    function pool(name: string): var {
        const all = Wallpapers.list;
        if (name === "favourites")
            return all.filter(w => isFavourite(w.path));
        if (name === "videos")
            return all.filter(w => isVideo(w.path));
        if (name === "images")
            return all.filter(w => !isVideo(w.path));
        return all;
    }

    function shuffle(poolName: string): void {
        let candidates = pool(poolName || "all").filter(w => w.path !== Wallpapers.actualCurrent);
        if (candidates.length === 0)
            candidates = pool("all").filter(w => w.path !== Wallpapers.actualCurrent);
        if (candidates.length === 0)
            return;
        Wallpapers.setWallpaper(candidates[Math.floor(Math.random() * candidates.length)].path);
    }

    function setSlideshow(minutes: int, poolName: string): void {
        slideshowMinutes = Math.max(0, minutes);
        if (poolName)
            slideshowPool = poolName;
        save();
    }

    function setFilter(name: string): void {
        if (filter === name)
            return;
        filter = name;
        save();
    }

    function setVideoQuality(quality: string): void {
        videoQuality = quality;
        Quickshell.execDetached([cacheTool, "quality", quality]);
    }

    function rebuildCache(): void {
        Quickshell.execDetached([cacheTool, "build", "--async"]);
    }

    // ---- Persistance ----

    function save(): void {
        if (stateLoaded)
            saveTimer.restart();
    }

    function load(text: string): void {
        let data = {};
        try {
            data = JSON.parse(text) ?? {};
        } catch (e) {
            data = {};
        }
        favourites = Array.isArray(data.favourites) ? data.favourites : [];
        themes = data.themes && typeof data.themes === "object" ? data.themes : {};
        transition = typeof data.transition === "string" ? data.transition : "random";
        slideshowMinutes = Number.isInteger(data.slideshowMinutes) ? data.slideshowMinutes : 0;
        slideshowPool = typeof data.slideshowPool === "string" ? data.slideshowPool : "all";
        filter = typeof data.filter === "string" ? data.filter : "all";
        activeTransition = transition === "random" ? pickRandom() : (transition === "config" ? "" : transition);
        stateLoaded = true;
    }

    Timer {
        id: saveTimer

        interval: 400
        onTriggered: stateFile.setText(JSON.stringify({
                favourites: root.favourites,
                themes: root.themes,
                transition: root.transition,
                slideshowMinutes: root.slideshowMinutes,
                slideshowPool: root.slideshowPool,
                filter: root.filter
            }, null, 2))
    }

    FileView {
        id: stateFile

        path: root.statePath
        printErrors: false
        atomicWrites: true
        onLoaded: root.load(text())
        onLoadFailed: root.load("{}")
    }

    FileView {
        path: root.indexPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.items = data.items ?? {};
                root.videoQuality = data.quality ?? "auto";
                root.targetHeight = data.target ?? 1080;
            } catch (e) {
                // Index en cours d'écriture : le prochain changement le relira.
            }
        }
    }

    // Diaporama
    Timer {
        running: root.slideshowMinutes > 0
        repeat: true
        interval: Math.max(1, root.slideshowMinutes) * 60000
        onTriggered: {
            if (!RuntimeState.gameMode)
                root.shuffle(root.slideshowPool);
        }
    }

    // Prépare les vidéos ajoutées/retirées du dossier.
    Timer {
        id: rebuildTimer

        interval: 2500
        onTriggered: root.rebuildCache()
    }

    Connections {
        function onListChanged(): void {
            rebuildTimer.restart();
        }

        target: Wallpapers
    }

    Component.onCompleted: rebuildTimer.restart()

    IpcHandler {
        function shuffle(pool: string): void {
            root.shuffle(pool);
        }

        function setTransition(name: string): void {
            root.setTransition(name);
        }

        function getTransition(): string {
            return root.transition;
        }

        function listTransitions(): string {
            return ["random", "config", ...root.transitions].join("\n");
        }

        function toggleFavourite(): void {
            root.toggleFavourite(Wallpapers.actualCurrent);
        }

        function setTheme(mode: string, variant: string): void {
            root.setTheme(Wallpapers.actualCurrent, mode || "auto", variant || "auto");
        }

        function slideshow(minutes: int): void {
            root.setSlideshow(minutes, "");
        }

        target: "wallstudio"
    }
}
