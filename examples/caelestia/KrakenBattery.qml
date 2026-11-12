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
    // Dock plugged in but not answering queries: commands still reach the
    // headset, only the battery level is unknown.
    readonly property bool dockSilent: _dockSilent
    readonly property bool present: _available || _dockSilent
    // Dock plugged in but mute, with no cable fallback: show a link-error
    // warning. Replugging the dock's USB (a real power cycle -- a reboot
    // keeps USB powered) brings it back.
    readonly property bool linkError: _dockSilent && !_available

    // Re-applies the last RGB color once the headset comes back online
    // (covers the RF-only power-cycle case, which fires no udev event).
    onAvailableChanged: {
        if (available)
            Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/kraken", "lights", "restore"]);
    }

    property bool _available: false
    property int _percentage: 0
    property bool _charging: false
    property string _via: ""
    property bool _dockSilent: false
    // tras conectar/desconectar el cable, el auricular tarda unos segundos en
    // re-engancharse por RF al dock: reintentar antes de dar por perdido
    property int _retriesLeft: 0

    Process {
        id: proc

        command: [Quickshell.env("HOME") + "/.local/bin/kraken", "battery", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let ok = false;
                let silent = false;
                try {
                    const info = JSON.parse(text);
                    silent = info.dock_silent === true;
                    if (typeof info.battery === "number") {
                        root._percentage = info.battery;
                        root._charging = !!info.charging;
                        root._via = info.via ?? "";
                        root._available = true;
                        ok = true;
                    }
                } catch (e) {}
                root._dockSilent = silent;
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
        // Fast enough to notice an RF-only headset power-cycle (no udev
        // event fires for that case) without much overhead.
        interval: 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
}
