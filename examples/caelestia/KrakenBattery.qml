pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool available: _available
    readonly property int percentage: _percentage
    readonly property bool charging: _charging
    readonly property string via: _via

    property bool _available: false
    property int _percentage: 0
    property bool _charging: false
    property string _via: ""

    Process {
        id: proc

        command: [Quickshell.env("HOME") + "/.local/bin/kraken-battery", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const info = JSON.parse(text);
                    if (typeof info.battery === "number") {
                        root._percentage = info.battery;
                        root._charging = !!info.charging;
                        root._via = info.via ?? "";
                        root._available = true;
                    } else {
                        root._available = false;
                    }
                } catch (e) {
                    root._available = false;
                }
            }
        }
    }

    // Refresco inmediato al conectar/desconectar el cable USB o el dock:
    // los eventos hidraw del kernel incluyen el VID:PID en el devpath.
    Process {
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=hidraw"]
        stdout: SplitParser {
            onRead: segment => {
                if (segment.includes("1532:0567") || segment.includes("1532:0568"))
                    debounce.restart();
            }
        }
    }

    Timer {
        id: debounce

        // le da tiempo al dispositivo a terminar de enumerar antes de consultar
        interval: 1500
        onTriggered: proc.running = true
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
}
