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
    // tras conectar/desconectar el cable, el auricular tarda unos segundos en
    // re-engancharse por RF al dock: reintentar antes de dar por perdido
    property int _retriesLeft: 0

    Process {
        id: proc

        command: [Quickshell.env("HOME") + "/.local/bin/kraken-battery", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let ok = false;
                try {
                    const info = JSON.parse(text);
                    if (typeof info.battery === "number") {
                        root._percentage = info.battery;
                        root._charging = !!info.charging;
                        root._via = info.via ?? "";
                        root._available = true;
                        ok = true;
                    }
                } catch (e) {}
                if (!ok) {
                    if (root._retriesLeft > 0) {
                        root._retriesLeft--;
                        retry.restart();
                    } else {
                        root._available = false;
                    }
                } else {
                    root._retriesLeft = 0;
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
        onTriggered: {
            root._retriesLeft = 4;
            proc.running = true;
        }
    }

    Timer {
        id: retry

        interval: 3000
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
