pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool on: _on
    readonly property color current: _current

    property bool _on: false
    property color _current: "#00c8ff"

    readonly property string _bin: Quickshell.env("HOME") + "/.local/bin/kraken-rgb"

    function setColor(r: int, g: int, b: int): void {
        Quickshell.execDetached([root._bin, `${r}`, `${g}`, `${b}`]);
        root._current = Qt.rgba(r / 255, g / 255, b / 255, 1);
        root._on = true;
    }

    function toggle(): void {
        Quickshell.execDetached([root._bin, "toggle"]);
        root._on = !root._on;
    }

    function off(): void {
        Quickshell.execDetached([root._bin, "off"]);
        root._on = false;
    }
}
