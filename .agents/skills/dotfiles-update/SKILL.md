---
name: dotfiles-update
description: "Update dotfiles locally + propagate to LinuxBro/SuperBro. Handles git clean, push, and remote bootstrap. Triggered by /dotfiles or .dotfiles"
trigger: /dotfiles
group: productivity
---

# Dotfiles Update

Updates dotfiles on all machines. Run from `~/dotfiles`.

## Steps

### 1. Check local git state

```bash
git -C ~/dotfiles status --porcelain
git -C ~/dotfiles log --oneline origin/master..HEAD
```

If dirty files exist: stage + commit them first.
If commits ahead of origin: note — will push after local update succeeds.

### 2. Run local update

```bash
dotfiles --update
```

Expected: `✓ Pulled latest from git` + `All modules up to date.`

If pull fails: most likely cause is dirty `devices/*.json` or case-conflict. Check with `git ls-files --cached .claude/devices/` for duplicates.

### 3. Push if ahead of origin

```bash
git -C ~/dotfiles push
```

Only push if dotfiles is in `~/.claude/push-whitelist.txt`. If not: tell user to push manually.

### 4. Propagate to LinuxBro

SSH in and run:
```bash
git -C ~/dotfiles pull && DOTFILES_NONINTERACTIVE=1 DOTFILES_WORKFLOWS=server ~/dotfiles/bootstrap.sh --only=symlinks,opencode
```

### 5. Propagate to SuperBro

Same as LinuxBro:
```bash
git -C ~/dotfiles pull && DOTFILES_NONINTERACTIVE=1 DOTFILES_WORKFLOWS=server ~/dotfiles/bootstrap.sh --only=symlinks,opencode
```

### 5b. Propagate to MonsterBro (Windows 11 WSL) — optional

Gaming rig, sometimes off. Skip unless explicitly requested or machine is confirmed online via Tailscale.

```bash
# Check if online first
ping -c1 monsterbro 2>/dev/null && echo "online" || echo "offline — skip"

# If online:
ssh monsterbro 'git -C ~/dotfiles pull && DOTFILES_NONINTERACTIVE=1 DOTFILES_WORKFLOWS=wsl ~/dotfiles/bootstrap.sh --only=symlinks,opencode'
```

Note: `wsl` workflow not yet defined — use `server` as fallback until `mcp-servers.wsl.list` is created.

### 6. Verify effort classifier active on all machines

After each remote update, check:
```bash
grep -q "effort-classifier" ~/dotfiles/.claude/settings.local.json && echo "OK" || echo "MISSING"
```

### 7. Confirm

One line: what updated, any failures, what's next.

## Gotchas

- `LinuxBro.json` was case-conflicting with `linuxbro.json` — fixed 2026-06-12. If dirty device files block pull: `git ls-files --cached .claude/devices/` to detect duplicates, `git rm --cached` to fix.
- Pre-commit hook fires during `git stash` — fixed 2026-06-12 with `GIT_REFLOG_ACTION` guard. If stash still blocks: update hooks first.
- `dotfiles --update` on server requires `DOTFILES_NONINTERACTIVE=1` or it hangs waiting for workflow picker input.
- `DOTFILES_WORKFLOWS` must be set before bootstrap or server MCPs won't install.
- `push-whitelist.txt` controls where `git push` is allowed — `~/dotfiles` must be listed for Claude to push.
