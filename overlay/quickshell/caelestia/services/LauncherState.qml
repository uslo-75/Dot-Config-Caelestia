pragma Singleton

import Quickshell

Singleton {
    id: root

    property string searchText: ""
    property int requestSerial: 0

    function openSearch(text: string): void {
        searchText = text;
        requestSerial++;
    }

    function clear(): void {
        searchText = "";
    }
}
