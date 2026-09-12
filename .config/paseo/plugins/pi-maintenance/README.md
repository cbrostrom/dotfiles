# Pi maintenance

Paseo plugin that checks Pi and configured Pi extension packages without using an agent or model tokens.

- Checks at most once every 24 hours per daemon plugin process.
- Shows a composer pill on Pi agents only when updates are available.
- Provides **Command Center → Check Pi updates** and a manual refresh screen.
- Never installs updates. Run `pi update --all` manually after review.

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
