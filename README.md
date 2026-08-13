# kraken-v4-pro-battery

Read the battery level of the **Razer Kraken V4 Pro** headset on Linux, with no
Synapse and no OpenRazer required. Works both wirelessly (through the dock) and
over the USB-C cable.

```
$ kraken-battery
Batería: 84% (en uso, vía dock/RF)
```

As of August 2026, OpenRazer has no support for this device (dock `1532:0568`,
headset `1532:0567`) and the kernel exposes no standard HID battery interface
for it. This script talks the same proprietary HID protocol Razer Synapse uses,
reverse-engineered from a USB capture (`usbmon` on the host while Synapse ran in
a Windows VM with the dock passed through).

## Install

```sh
install -m 755 kraken-battery ~/.local/bin/
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

## Notes

- Python 3 standard library only, no dependencies.
- The script tries the wired headset first, then the dock (RF).
- Battery reporting resolution is 1%; expect the first drop from 100% to take a
  while (the headset runs tens of hours per charge).
