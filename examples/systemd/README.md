# systemd user service for kraken-eq-watch

Runs `kraken-eq-watch` continuously so you get a desktop notification
whenever the EQ preset changes via the physical button on the headset
(see the main README for why polling is needed instead of just listening).

## Install

```sh
mkdir -p ~/.config/systemd/user
cp kraken-eq-watch.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now kraken-eq-watch.service
```

Requires `kraken-eq` installed at `~/.local/bin/kraken-eq` (`kraken-eq-watch`
imports it directly by path) and `notify-send` (from `libnotify` or
equivalent) for the actual notifications.
