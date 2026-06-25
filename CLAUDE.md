# dotfiles

Personal dotfiles for macOS (GY-M-WHKK2PF6N7), LinuxBro, SuperBro, MonsterBro (Windows 11 WSL).

## Update

```bash
dotfiles --update          # local
/dotfiles                  # skill: local + propagate to servers
```

## Structure

| Path | Purpose |
|------|---------|
| `modules/` | Install units (claude-settings, mcp-servers, skills, symlinks, …) |
| `tui/` | Interactive update TUI (`dotfiles --update`) |
| `scripts/` | Standalone tools: `project-mcp.sh`, `agentsync.sh`, `device-snapshot.sh` |
| `hooks/` | Git hooks (pre-commit: syntax check + device snapshot) |
| `.claude/` | Claude Code config: settings, hooks, skills, devices |
| `.claude/hooks/` | Claude Code hooks: effort-classifier, brain-save-inject, brain-load, claude-settings-merge, git-push-guard, rtk-rewrite, statusline |
| `.claude/devices/` | Per-host Claude snapshots (auto-updated by pre-commit hook) |

## Settings layers

`settings.base.json` → `settings.{darwin,linux,wsl}.json` → `settings.override.json` (gitignored)

Merged into `settings.local.json` on SessionStart. **Never edit `settings.local.json` directly.**

After edits: `./modules/claude-settings/doctor.sh --fix`

## Key hooks

| Hook | Event | Purpose |
|------|-------|---------|
| `effort-classifier.sh` | UserPromptSubmit | Tier prompt complexity → inject `[eff:tier]` hint |
| `brain-save-inject.sh` | PreCompact + UserPromptSubmit(/compact) | Write brain files before context loss |
| `brain-load.sh` | SessionStart | Inject vault context into session |
| `claude-settings-merge.sh` | SessionStart (async) | Regenerate `settings.local.json` when tracked inputs change |
| `git-push-guard.sh` | PreToolUse[Bash] | Block `git push` outside whitelist |
| `statusline.sh` | statusLine | Shell command for status bar |

## Workflows

`DOTFILES_WORKFLOWS` in `~/.zshrc.local` controls which MCP list loads.

| Value | MCPs loaded | Used on |
|-------|-------------|---------|
| `developer` | full set | Mac |
| `work` | atlassian via project-mcp | Mac |
| `server` | `mcp-servers.server.list` | LinuxBro, SuperBro |
| `wsl` | `mcp-servers.wsl.list` (TBD) | MonsterBro (WSL) |

## Per-project MCPs

```bash
project-mcp add akqa       # injects atlassian-akqa into .claude/settings.json
project-mcp add fiskars    # injects atlassian-fiskars
project-mcp add shopify    # injects shopify-dev
project-mcp list           # show active
project-mcp remove akqa    # remove
```

## Gotchas

- Pre-commit hook fires during `git stash` — skip guard added via `GIT_REFLOG_ACTION`. Stash no longer re-dirtied.
- Device snapshots use `hostname -s` (lowercase) — canonical: `linuxbro.json`, `superbro.json`. Never `LinuxBro.json`.
- `dotfiles --update` on server: must have `DOTFILES_NONINTERACTIVE=1` or hangs at workflow picker.
- `git pull --rebase` blocked by dirty files: check `git ls-files --cached .claude/devices/` for case duplicates.
