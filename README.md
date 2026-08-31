# kraken-v4-pro-battery

Read the battery level, control the RGB lighting, and switch EQ presets on the
**Razer Kraken V4 Pro** headset on Linux, with no Synapse and no OpenRazer
required. Works both wirelessly (through the dock) and over the USB-C cable.

```
$ kraken battery
Battery: 84% (discharging, via dock/RF)

$ kraken battery --json
{"battery": 84, "charging": false, "via": "dock/RF"}

$ kraken lights 255 0 0
RGB: 255,0,0 (via cable)
$ kraken lights toggle
RGB: 0,0,0 (via cable)

$ kraken eq movie
EQ: Movie
```

The `--json` output is meant for status bars and scripts (waybar, quickshell,
polybar…); on failure it prints `{"error": "..."}` and exits non-zero. See
[`examples/caelestia/`](examples/caelestia/) for a ready-made bar widget for
the Caelestia shell (icon + Synapse-style popout with instant plug/unplug
updates, plus color swatches and an on/off toggle), and
[`examples/systemd/`](examples/systemd/) for a service that sends a desktop
notification whenever the EQ preset changes via the headset's button.

As of August 2026, OpenRazer has no support for this device (dock `1532:0568`,
headset `1532:0567`) and the kernel exposes no standard HID battery interface
for it. This script talks the same proprietary HID protocol Razer Synapse uses,
reverse-engineered from a USB capture (`usbmon` on the host while Synapse ran in
a Windows VM with the dock passed through).

## Install

```sh
install -m 755 kraken ~/.local/bin/
install -Dm 644 dock-recovery-sequence.hex ~/.local/share/kraken-rgb/dock-recovery-sequence.hex
sudo install -m 644 70-kraken-battery.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=hidraw --action=add
```

The udev rule grants your logged-in user access to the headset's `hidraw`
nodes via the systemd `uaccess` tag. The file **must** sort before `73` —
`uaccess` ACLs are applied by systemd's `73-seat-late.rules`, so a `99-*` rule
tags too late and silently does nothing.

## Protocol

Commands are 64-byte HID output reports (report ID `0x02`) sent with
`SET_REPORT` to the vendor HID interface (the second `hidraw` of `1532:0568`;
the first one rejects writes with `EPIPE`). Responses arrive as 64-byte input
reports on the same interface.

```
request:  02 00 60 00 00 00 04 00 | 00 TT CC 00 | 00 …
response: 02 02 60 00 00 00 LL 00 | 00 TT CC 01 | VV BB …
```

- `TT` — target: `0x80` = wireless headset via the dock, `0x00` = wired headset
  (`1532:0567`) directly.
- `CC` — command ID:
  | command | meaning | `BB` value |
  |---------|---------|------------|
  | `0x21`  | battery level | `0`–`100` (`0xFF` = no RF link to headset) |
  | `0x2a`  | charging      | `01` charging, `00` on battery |
  | `0x20`  | RF link state | `01` headset linked to dock, `00` not |
- `VV` (byte 12) — "data valid" flag, always `01` on a good reply. It is **not**
  the charging state (easy trap: it never changes).
- The dock also pushes an unsolicited status frame (`… 80 80 20 02 02 …`) every
  ~5 s on the same endpoint, so responses must be matched by the command byte
  at offset 10.

Validated byte-for-byte against Synapse: a fresh Synapse session querying the
wireless headset displayed exactly the value returned by command `0x21`
(`0x64` = 100%), and both readings tracked together as the battery drained.

## RGB lighting

`kraken lights` sets the earcup RGB ring to a solid color, or turns it off,
using two different paths depending on how the headset is connected:

- **Wired (USB-C cable)** — preferred. A plain 64-byte HID output report
  (report ID `0x02`) to the headset's own `hidraw` interface (`1532:0567`),
  no setup required. Confirmed reliable across real cable unplug/replug
  cycles.
- **Dock/RF (wireless)** — fallback when no cable is connected. Same report,
  sent to the dock (`1532:0568`) instead, but the dock silently ignores it
  after the *headset* has been power-cycled until it sees the same recovery
  sequence Synapse sends on reconnect: `kraken lights` replays
  [`dock-recovery-sequence.hex`](dock-recovery-sequence.hex) (55 config/
  telemetry/capability queries, captured from a real Synapse reconnect and
  filtered down from the original 140 by dropping the lighting-animation
  frames that were also in the capture — replaying those caused a visible
  flash through unrelated colors on every write) before every dock-path
  write. Commands need ~20ms spacing — sending them with no delay floods the
  dock and only some land. Adds ~1s but is fully reliable; confirmed across
  repeated real headset power-cycles with no Synapse/Windows involved at all.

`kraken lights restore` re-applies the last color used (reads `~/.cache/
kraken-rgb-state`) without changing it — meant to be triggered automatically
once something notices the headset came back online, since a headset-only
power-cycle raises no udev event on its own (the dock's USB connection never
drops). See [`examples/caelestia/`](examples/caelestia/) for a working
example wired into a battery-availability poll.

```
02 00 60 00 00 00 21 0f 03 TT 00 00 00 00 08 | RR GG BB RR GG BB …
```

`TT` (byte 9) is `0x00` for the wired path, `0x80` for the dock. The header is
otherwise identical; the R,G,B triplet is tiled from byte 15 to the end of
the report.

**Gotcha if you're extending this:** never send the Feature report handshake
on the wired interface. Doing so corrupts it into only lighting one of the
ring's ~10 individually-addressable LED zones instead of the whole ring, and
that persists until the cable is unplugged and replugged — it isn't
reversible in software. The handshake is dock-only.

## EQ presets

`kraken eq` reads or switches the active EQ preset (dock/RF only — untested
over the wired path). Same 64-byte report family as battery/charging, a
different command pair:

```
request:  02 00 60 00 00 00 05 00 | 00 80 CC 00 | …
response: 02 02 60 00 00 00 05 00 | 00 80 CC 01 | 01 PP 00 00
```

`CC=0x93` is SET — unlike a plain query, the request body itself carries the
target preset (`01 PP 00 00` right after the header) and applying it takes
effect immediately, no separate "commit" step. `CC=0x13` is GET — a plain
query (same shape as the battery/charging ones), returns the *current*
preset in the response's `PP` byte. `PP`, confirmed by ear with real audio
and by round-tripping set-then-get:

```
$ kraken eq movie
EQ: Movie
$ kraken eq status
EQ: Movie
```

| Preset | ID |
|--------|----|
| `game` | `0x07` |
| `music` | `0x08` |
| `movie` | `0x09` |
| `custom` | `0xff` |

A single write is enough for SET — unlike the RGB dock path, this one did
**not** need the recovery-sequence replay in testing (in fact replaying it
first caused the following EQ write to time out, so don't add it back
without re-testing carefully). Not yet confirmed whether this survives a
real headset power-cycle the way RGB needed the recovery sequence for.

A separate command (`0x95`) returns the active preset's 10-band gain array —
not needed just to read/switch the preset name.

**No notification for the physical preset button on its own.** The dock does
NOT push an unsolicited notification when the button is pressed with nothing
else polling — confirmed by testing repeatedly with a raw hidraw listener
and no traffic ever appeared, on both host-only and right after replaying
the RGB recovery sequence. The `CC=0x13` traffic that shows up in USB
captures only happens because Synapse's own EQ UI is being actively clicked
in — not from sitting idle with the tab open, and not from the headset
button alone. `kraken watch` works around this by actively polling
`CC=0x13` itself (every 150ms) and firing a desktop notification
(`notify-send`) whenever the reported preset changes — see
[`examples/systemd/`](examples/systemd/) for the service unit that runs it
continuously.

## Volume, output, and balance

This device exposes two independent USB Audio playback interfaces, "Game"
and "Chat" (matching Synapse's own naming) — each one an *input* to an
on-device Game-Chat balance mixer, not two separate physical outputs. Each
one has both a PipeWire-side software volume and its own real hardware
gain, controllable independently:

```
$ kraken output game               # switch the active output, no volume change
$ kraken volume game 40            # PipeWire's own software level (0-100)
$ kraken volume master game 75     # the device's REAL gain (0-100, needs amixer)
$ kraken volume status --json
{"output": "game", "pipewire": {"chat": 50, "game": 40}, "master": {"chat": 100, "game": 75}}
```

`chat`/`game` is optional on `volume`/`volume master` and defaults to
`game`. `volume master` needs `amixer` (`alsa-utils`) — everything else
here only needs `pactl`.

Both ALSA controls (`'PCM',0` for Chat, `'PCM',1` for Game — check
`amixer -c N scontrols` if your build gives them different names/indices)
were already exposed by the kernel's own `snd-usb-audio` driver the whole
time; no root or raw USB access is needed. `volume master` doesn't use
`amixer`'s own linear percentage, though — that's linear *in dB*, which is
exponential in perceived loudness (dB is already a log scale), so it makes
the bottom ~70% of the range feel like almost nothing changes and the last
~20% do all the work. It uses Synapse's own real percent→dB curve instead
(captured from live hardware traffic: 3%→-49.93dB, 50%→-10.42dB,
100%→0dB), so each step feels roughly even by ear.

Both sinks show up in PipeWire with unhelpful names by default ("Razer
Kraken V4 Pro" and "Razer Kraken V4 Pro (USB Audio #1)") — drop this into
`~/.config/wireplumber/wireplumber.conf.d/51-razer-kraken.conf` and
`systemctl --user restart wireplumber` to rename them to "Kraken V4 Pro
(Chat)"/"(Game)" in any output picker:

```conf
# Expose both ALSA PCM subdevices (Chat + Game) instead of letting
# alsa-card-profile (ACP) collapse them into one profile that only binds
# to Chat, and give each a readable name.
monitor.alsa.rules = [
  {
    matches = [{ device.vendor.id = "0x1532", device.product.id = "0x0568" }]
    actions = { update-props = { api.alsa.use-acp = false } }
  }
  {
    matches = [{ node.name = "alsa_output.usb-Razer_Kraken_V4_Pro_-_Chat_Razer_Kraken_V4_Pro-00.playback.0.0" }]
    actions = { update-props = { node.description = "Kraken V4 Pro (Chat)", node.nick = "Kraken V4 Pro (Chat)" } }
  }
  {
    matches = [{ node.name = "alsa_output.usb-Razer_Kraken_V4_Pro_-_Chat_Razer_Kraken_V4_Pro-00.playback.1.0" }]
    actions = { update-props = { node.description = "Kraken V4 Pro (Game)", node.nick = "Kraken V4 Pro (Game)" } }
  }
]
```

If `pactl list sinks` shows different `node.name`s on your setup (different
card index, different USB port), edit the two `matches` above to match —
only the `.playback.0.0`/`.playback.1.0` suffix (Chat/Game) actually
matters.

`kraken balance <0-20>` sets the on-device Game-Chat crossfade (Synapse's
"EQUILIBRIO JUEGO-CHAT" slider) — `0` = full Game, `20` = full Chat, `10` =
centered. Same safe HID report channel as RGB/EQ/mic, no ALSA/root needed.
This crossfades between whatever's currently feeding each mix input,
scaled by each one's own volume above — it doesn't route specific apps to
Chat vs Game on its own.

## Mic monitoring

```
$ kraken mic monitor on             # sidetone ("tono local"), on/off
$ kraken mic monitor-volume 8       # 0-15, matches Synapse's own slider range
```

Dock/RF only, same 64-byte report family as everything above. Mic mute and
mic capture volume (the main ones, not sidetone) aren't implemented — see
the `kraken` script's "mic" section docstring for why.

## Notes

- Python 3 standard library only, no pip packages -- but a few subcommands
  shell out to external tools that must be installed separately:
  `kraken volume`/`kraken output` need `pactl` (PipeWire or PulseAudio),
  `kraken volume master` needs `amixer` (the `alsa-utils` package), and
  `kraken watch` needs `notify-send` (`libnotify`). Everything else
  (battery/lights/eq/mic/balance) has no extra dependency beyond the udev
  rule above.
- The script tries the wired headset first, then the dock (RF).
- Battery reporting resolution is 1%; expect the first drop from 100% to take a
  while (the headset runs tens of hours per charge).
