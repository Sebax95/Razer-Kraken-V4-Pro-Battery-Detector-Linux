pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string current: _current

    property string _current: ""

    readonly property string _bin: Quickshell.env("HOME") + "/.local/bin/kraken-eq"

    function setPreset(name: string): void {
        Quickshell.execDetached([root._bin, name]);
        root._current = name;
    }

    function refresh(): void {
        statusProc.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: statusProc

        command: [root._bin, "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const info = JSON.parse(text);
                    if (info.preset)
                        root._current = info.preset;
                } catch (e) {}
            }
        }
    }
}
