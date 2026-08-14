# kraken-v4-pro-battery

Read the battery level and control the RGB lighting of the **Razer Kraken V4
Pro** headset on Linux, with no Synapse and no OpenRazer required. Works both
wirelessly (through the dock) and over the USB-C cable.

```
$ kraken-battery
Battery: 84% (discharging, via dock/RF)

$ kraken-battery --json
{"battery": 84, "charging": false, "via": "dock/RF"}

$ kraken-rgb 255 0 0
RGB: 255,0,0 (via cable)
$ kraken-rgb toggle
RGB: 0,0,0 (via cable)
```

The `--json` output is meant for status bars and scripts (waybar, quickshell,
polybar…); on failure it prints `{"error": "..."}` and exits non-zero. See
[`examples/caelestia/`](examples/caelestia/) for a ready-made bar widget for
the Caelestia shell (icon + Synapse-style popout with instant plug/unplug
updates, plus color swatches and an on/off toggle).

As of August 2026, OpenRazer has no support for this device (dock `1532:0568`,
headset `1532:0567`) and the kernel exposes no standard HID battery interface
for it. This script talks the same proprietary HID protocol Razer Synapse uses,
reverse-engineered from a USB capture (`usbmon` on the host while Synapse ran in
a Windows VM with the dock passed through).

## Install

```sh
install -m 755 kraken-battery kraken-rgb ~/.local/bin/
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

`kraken-rgb` sets the earcup RGB ring to a solid color, or turns it off, using
two different paths depending on how the headset is connected:

- **Wired (USB-C cable)** — preferred. A plain 64-byte HID output report
  (report ID `0x02`) to the headset's own `hidraw` interface (`1532:0567`),
  no setup required. Confirmed reliable across real cable unplug/replug
  cycles.
- **Dock/RF (wireless)** — fallback when no cable is connected. Same report,
  sent to the dock (`1532:0568`) instead, but the dock silently ignores it
  unless a one-time HID *Feature* report handshake (`HIDIOCSFEATURE`, not a
  plain write) has been sent first on the current USB connection. That
  handshake does **not** survive the *headset* itself being power-cycled
  (only a fresh dock-side USB connection resets it) — a real limitation of
  the dock's firmware, not something this script can currently route around
  for RF-only setups.

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

## Notes

- Python 3 standard library only, no dependencies.
- The script tries the wired headset first, then the dock (RF).
- Battery reporting resolution is 1%; expect the first drop from 100% to take a
  while (the headset runs tens of hours per charge).
