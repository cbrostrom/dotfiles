# Pi Settings Sync Strategy

Pi settings live in two places:
- **~/.pi/agent/settings.json** — runtime state (what Pi actually uses)
- **~/dotfiles/.config/pi/agent/settings.base.json** — version-controlled baseline

The pi module merges these: dotfiles baseline + runtime fields → ~/.pi/agent/settings.json

## Problem

Over time, ~/.pi/agent/settings.json drifts from dotfiles:
- Packages get added/removed in Pi
- Model/theme preferences change
- New features add new config fields

This breaks Orca sync (it reads ~/.pi/agent/settings.json, not the dotfiles baseline).

## Solutions

### 1. Manual sync (one-liner)

Run when you change Pi settings (model, packages, theme, etc.):

```bash
pi-sync-settings
```

Then commit:

```bash
cd ~/dotfiles && git add .config/pi/agent/settings.base.json && git commit -m "Pi settings sync"
```

---

### 2. Git hook (automatic on dotfiles pull)

Add to `~/dotfiles/.git/hooks/post-merge`:

```bash
#!/bin/bash
# Auto-sync Pi settings after git pull
if command -v pi >/dev/null 2>&1; then
    echo "[dotfiles] Running pi module to sync settings..."
    bash "$PWD/modules/pi/install.sh"
fi
```

Enable:

```bash
chmod +x ~/dotfiles/.git/hooks/post-merge
```

---

### 3. Brain task (kb reminder)

Document as a periodic maintenance task in brain:

```bash
kb next "Sync Pi settings to dotfiles: pi-sync-settings && git add .config/pi/agent/settings.base.json && git commit"
```

Then pick it up in standup/morning-brief cycle.

---

### 4. Dotfiles module (automatic on `dotfiles --update`)

Already handled. Running `dotfiles --update` re-runs the pi module, which merges latest settings.

**But:** Only works if settings.base.json is current. So combine with Option 1 (manual sync) → commit → then `dotfiles --update` on next machine.

---

## Recommended workflow

1. **On this machine:** Keep pi-sync-settings in PATH (already done)
2. **After Pi config changes:** Run `pi-sync-settings` + commit
3. **On other machines:** Run `dotfiles --update` to pull latest
4. **Optional:** Add post-merge hook for automation

## When to sync

- After changing:
  - Default model or provider
  - Packages (installing/removing extensions)
  - Theme
  - Extensions
  - Any field in settings.json UI

- Before:
  - Switching machines
  - Committing config changes
  - Major Pi version update
