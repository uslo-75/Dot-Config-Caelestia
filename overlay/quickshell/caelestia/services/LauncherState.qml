pragma Singleton

import Quickshell

// Mode demandé à l'ouverture du launcher ("" = applications, "wallpapers", "clipboard").
Singleton {
    id: root

    property string mode: ""
    property int requestSerial: 0

    function open(mode: string): void {
        root.mode = mode;
        requestSerial++;
    }

    function clear(): void {
        mode = "";
    }
}
