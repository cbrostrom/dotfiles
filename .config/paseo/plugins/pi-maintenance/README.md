# Pi maintenance

Paseo plugin that checks Pi and configured Pi extension packages without using an agent or model tokens.

- Checks at most once every 24 hours per daemon plugin process.
- Shows a composer pill on Pi agents only when updates are available.
- Provides **Command Center → Check Pi updates** and a manual refresh screen.
- **Update now** runs `pi update --all` detached on the daemon machine — it survives
  the RPC call and a daemon restart, appends to `~/.pi/agent/paseo-pi-update.log`, and
  the screen polls progress every 2 s and re-checks what is outdated when it finishes.
  A run already in progress is never started twice.

## Install

```bash
cd ~/dotfiles/.config/paseo/plugins/pi-maintenance
npm install
npm run typecheck
paseo plugin install "$PWD"
```

## Verify

```bash
paseo plugin ls pi-maintenance
paseo plugin logs pi-maintenance
```
