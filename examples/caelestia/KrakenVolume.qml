pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string output: _output
    readonly property real pipewireChat: _pipewireChat
    readonly property real pipewireGame: _pipewireGame
    readonly property real masterChat: _masterChat
    readonly property real masterGame: _masterGame
    // 0 = full "game" extreme, 1 = full "chat" extreme, 0.5 = centered --
    // mirrors the device's own native 0-20 range (kraken balance <0-20>).
    readonly property real balance: _balance

    property string _output: "game"
    property real _pipewireChat: 0
    property real _pipewireGame: 0
    property real _masterChat: 0
    property real _masterGame: 0
    property real _balance: 0.5

    readonly property string _bin: Quickshell.env("HOME") + "/.local/bin/kraken"

    function refresh(): void {
        statusProc.running = true;
    }

    function setOutput(target: string): void {
        Quickshell.execDetached([root._bin, "output", target]);
        root._output = target;
    }

    function setVolume(target: string, value: real): void {
        const pct = Math.round(value * 100);
        Quickshell.execDetached([root._bin, "volume", target, String(pct)]);
        if (target === "chat")
            root._pipewireChat = value;
        else
            root._pipewireGame = value;
        root._output = target;
    }

    // No way to read the balance back (fire-and-forget vendor command, no
    // ALSA/pactl-visible state for it) -- tracked locally only, resets to
    // centered (0.5) on reload.
    function setBalance(value: real): void {
        const raw = Math.round(value * 20);
        Quickshell.execDetached([root._bin, "balance", String(raw)]);
        root._balance = value;
    }

    function setMaster(target: string, value: real): void {
        const pct = Math.round(value * 100);
        Quickshell.execDetached([root._bin, "volume", "master", target, String(pct)]);
        if (target === "chat")
            root._masterChat = value;
        else
            root._masterGame = value;
    }

    Component.onCompleted: refresh()

    Process {
        id: statusProc

        command: [root._bin, "volume", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const info = JSON.parse(text);
                    if (info.output)
                        root._output = info.output;
                    if (typeof info.pipewire?.chat === "number")
                        root._pipewireChat = info.pipewire.chat / 100;
                    if (typeof info.pipewire?.game === "number")
                        root._pipewireGame = info.pipewire.game / 100;
                    if (typeof info.master?.chat === "number")
                        root._masterChat = info.master.chat / 100;
                    if (typeof info.master?.game === "number")
                        root._masterGame = info.master.game / 100;
                } catch (e) {}
            }
        }
    }

    Timer {
        // Catches changes made outside this app (physical wheel, another
        // volume control) -- not urgent, so a modest interval is fine.
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
