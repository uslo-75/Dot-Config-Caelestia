pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

// Outils de capture : texte d'une zone (reconnaissance de caractères), QR code (lu dans une
// zone ou créé depuis le presse-papiers), pipette, GIF d'une zone. Le travail est fait par
// ~/.local/bin/caelestia-capture, qui prévient par une notification (y compris quand un
// programme manque). Réglages : section `capture` d'extras.json.
Singleton {
    id: root

    readonly property string tool: `${Paths.home}/.local/bin/caelestia-capture`
    readonly property bool recording: gif.running
    // Dernières couleurs relevées à la pipette (la plus récente d'abord).
    property var colours: []
    property bool loaded

    function run(args: var): void {
        Quickshell.execDetached([tool, ...args]);
    }

    function ocr(): void {
        const langs = Extras.capture.ocrLanguages.trim();
        run(langs ? ["ocr", "--langs", langs] : ["ocr"]);
    }

    function qr(): void {
        run(["qr"]);
    }

    function qrMake(): void {
        run(Extras.capture.directory ? ["qr-make", "--dir", Extras.capture.directory] : ["qr-make"]);
    }

    // Pipette : la couleur est copiée, gardée dans l'historique et annoncée.
    function colour(): void {
        if (!picker.running)
            picker.exec([tool, "colour"]);
    }

    // Bascule : démarre l'enregistrement d'une zone, ou l'arrête et le convertit en GIF.
    function gifToggle(): void {
        if (gif.running) {
            gif.signal(2); // SIGINT : le script termine l'enregistrement puis convertit.
            return;
        }
        const args = ["gif", "--fps", String(Extras.capture.gifFps), "--width", String(Extras.capture.gifWidth), "--max", String(Extras.capture.gifMaxSeconds)];
        if (Extras.capture.directory)
            args.push("--dir", Extras.capture.directory);
        gif.exec([tool, ...args]);
    }

    Process {
        id: gif
    }

    Process {
        id: picker

        stdout: StdioCollector {
            onStreamFinished: {
                const c = text.trim().split("\n").pop() ?? "";
                if (!/^#[0-9a-fA-F]{6}$/.test(c))
                    return;
                root.colours = [c, ...root.colours.filter(x => x !== c)].slice(0, 12);
                if (root.loaded)
                    stateFile.setText(JSON.stringify({
                        colours: root.colours
                    }));
                Quickshell.execDetached(["notify-send", "-a", "Capture", "Couleur copiée", c]);
            }
        }
    }

    FileView {
        id: stateFile

        path: `${Paths.state}/capture.json`
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.colours = Array.isArray(data?.colours) ? data.colours.filter(c => typeof c === "string") : [];
            } catch (e) {
                root.colours = [];
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    IpcHandler {
        // Texte d'une zone de l'écran, copié dans le presse-papiers.
        function ocr(): void {
            root.ocr();
        }

        // QR code d'une zone de l'écran, contenu copié.
        function qr(): void {
            root.qr();
        }

        // QR code du texte copié, enregistré et copié en image.
        function qrMake(): void {
            root.qrMake();
        }

        function colour(): void {
            root.colour();
        }

        // Démarre l'enregistrement d'une zone, ou l'arrête et le convertit en GIF.
        function gif(): void {
            root.gifToggle();
        }

        function isRecording(): string {
            return root.recording ? "1" : "0";
        }

        target: "capture"
    }
}
