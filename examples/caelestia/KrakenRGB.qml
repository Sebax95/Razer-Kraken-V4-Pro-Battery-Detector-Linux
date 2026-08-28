pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool on: _on
    readonly property color current: _current

    property bool _on: false
    property color _current: "#00c8ff"

    readonly property string _bin: Quickshell.env("HOME") + "/.local/bin/kraken"

    function _applyState(text: string): void {
        const parts = text.trim().split(",").map(Number);
        if (parts.length !== 3 || parts.some(isNaN))
            return;
        const [r, g, b] = parts;
        root._current = Qt.rgba(r / 255, g / 255, b / 255, 1);
        root._on = r !== 0 || g !== 0 || b !== 0;
    }

    function setColor(r: int, g: int, b: int): void {
        Quickshell.execDetached([root._bin, "lights", `${r}`, `${g}`, `${b}`]);
        root._current = Qt.rgba(r / 255, g / 255, b / 255, 1);
        root._on = true;
    }

    function toggle(): void {
        Quickshell.execDetached([root._bin, "lights", "toggle"]);
        root._on = !root._on;
    }

    function off(): void {
        Quickshell.execDetached([root._bin, "lights", "off"]);
        root._on = false;
    }

    // Reads the same state file `kraken lights` itself writes to/restores
    // from -- catches the case where the color was changed from outside
    // this app (a raw CLI call, a physical action) so the toggle doesn't
    // silently disagree with reality.
    FileView {
        path: Quickshell.env("HOME") + "/.cache/kraken-rgb-state"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._applyState(text())
    }
}
