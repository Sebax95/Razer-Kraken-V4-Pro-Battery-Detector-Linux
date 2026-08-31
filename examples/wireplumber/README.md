# WirePlumber config for the Kraken's two audio sinks

The Kraken V4 Pro dock exposes two independent ALSA PCM playback
subdevices ("Chat" and "Game", see the main README's "Volume, output, and
balance" section). Without these files, PipeWire/ACP collapses them into
one generic profile bound to only the Chat interface, and even once both
are visible, PipeWire gives them useless names in any output picker:
"Razer Kraken V4 Pro" and "Razer Kraken V4 Pro (USB Audio #1)" —
impossible to tell apart.

## Install

```sh
mkdir -p ~/.config/wireplumber/wireplumber.conf.d
cp 51-razer-kraken-no-acp.conf 52-razer-kraken-names.conf ~/.config/wireplumber/wireplumber.conf.d/
systemctl --user restart wireplumber
```

After that, both subdevices show up as separate outputs, named
"Kraken V4 Pro (Chat)" and "Kraken V4 Pro (Game)".

## Files

- `51-razer-kraken-no-acp.conf` — disables `alsa-card-profile` (ACP) for
  this device (`api.alsa.use-acp = false`), so both PCM subdevices are
  exposed as separate sinks instead of ACP collapsing them into one
  "analog-stereo" profile that only ever binds to Chat.
- `52-razer-kraken-names.conf` — renames each sink's `node.description`/
  `node.nick` by matching its exact `node.name`. If your `pactl list sinks`
  shows different sink names (different card index, different USB port
  string), edit the `node.name` matches in this file to match — the
  device-name portion (`Razer_Kraken_V4_Pro_-_Chat_Razer_Kraken_V4_Pro-00`)
  should be identical, only the leading `alsa_output.usb-` prefix and
  `.playback.N.0` suffix matter (`.0.0` = Chat, `.1.0` = Game).
