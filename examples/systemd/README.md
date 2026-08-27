# systemd user service for kraken watch

Runs `kraken watch` continuously so you get a desktop notification
whenever the EQ preset changes via the physical button on the headset
(see the main README for why polling is needed instead of just listening).

## Install

```sh
mkdir -p ~/.config/systemd/user
cp kraken-watch.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now kraken-watch.service
```

Requires `kraken` installed at `~/.local/bin/kraken` and `notify-send` (from
`libnotify` or equivalent) for the actual notifications.
