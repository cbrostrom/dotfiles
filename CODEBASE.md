# Codebase map — dotfiles

Read this before searching. Jump directly to the right file.

## Root

| File | Purpose |
|------|---------|
| `AGENTS.md` | AI agent policy, approval gate, brain protocol, push guard |
| `AGENT_SKILLS.md` | Skill inventory for all agents |
| `CLAUDE.md` | Claude Code–specific adapter (settings layers, key hooks) |
| `CODEBASE.md` | This file — directory/file index |
| `Brewfile` | macOS Homebrew packages |
| `install.sh` | Bootstrap entry point |
| `dotfiles.sh` | Main CLI (`dotfiles --update`, `dotfiles --status`) |
| `modules.conf` | Active modules list |
| `skills-lock.json` | Pinned skill versions |
| `VERSION` | Current dotfiles version |

## Key directories

### `modules/`
Install units. Each module has `install.sh` + optional `doctor.sh`.

| Module | Purpose |
|--------|---------|
| `claude-settings/` | Merge `settings.base.json` → OS layer → `settings.local.json` |
| `claude-config/` | Claude Code config sync |
| `claude-plugins/` | Plugin list management |
| `mcp-servers/` | MCP server list installation |
| `skills/` | Agent skill installation (`~/.agents/skills/`, `~/.cursor/skills`) |
| `symlinks/` | Dotfile symlink definitions |
| `zsh/` | Zsh config module |
| `packages/` | Cross-platform package install |
| `starship/` | Starship prompt config |
| `_lib/` | Shared module helpers |

### `zsh/`
Numbered zsh config files sourced in order:

| File | Purpose |
|------|---------|
| `00-performance.zsh` | Profiling / lazy loading |
| `01-environment.zsh` | `PATH`, env vars |
| `02-plugins.zsh` | Plugin manager (zgenom) |
| `03-aliases.zsh` | Shell aliases |
| `04-functions.zsh` | Shell functions |
| `05-integrations.zsh` | Tool integrations (fzf, zoxide, etc.) |
| `06-autoupdate.zsh` | Autoupdate logic |
| `08-workflow.zsh` | `DOTFILES_WORKFLOWS` switch, MCP list loading |
| `09-herdr.zsh` | Herdr integration |
| `lib/` | Shared zsh helpers |

### `scripts/`
Standalone tools symlinked to `~/.local/bin/`.

| Script | Purpose |
|--------|---------|
| `brain` | Brain CLI — `brain load/save/current/next/gotcha` |
| `project-mcp.sh` | Per-project MCP injection |
| `agentsync.sh` | Sync agent core files to servers |
| `agent-core-sync.sh` | Sync `.agents/` layer |
| `doctor.sh` | Dotfiles health check |
| `audit.sh` | Security/config audit |
| `ob` | Obsidian vault opener |
| `rtk` | Token-compression wrapper for shell commands |
| `cursor/` | Cursor-specific helpers |
| `claude/` | Claude Code–specific helpers |
| `session-check` | Session integrity check |
| `session-summarize` | Session summarizer |
| `vault/` | Vault helpers |
| `zsh/` | Zsh helpers |

### `.claude/`
Claude Code config (not symlinked — read in place by CC).

| Path | Purpose |
|------|---------|
| `hooks/` | CC hooks: effort-classifier, brain-load, brain-save-inject, git-push-guard, rtk-rewrite, statusline |
| `skills/` | Claude-only skills (not shared — promote to `.agents/skills/` to share) |
| `devices/` | Per-host Claude snapshots |
| `settings.base.json` | Base Claude settings |
| `settings.darwin.json` | macOS overrides |
| `settings.local.json` | Merged output — never edit directly |
| `mcp-servers.*.list` | MCP server lists per workflow |
| `push-whitelist.txt` | Repos where `git push` is allowed |

### `.cursor/`
Cursor IDE config.

| Path | Purpose |
|------|---------|
| `rules/` | Cursor rules (core.mdc, token-efficiency.mdc, etc.) |
| `hooks/` | Cursor hooks |
| `agents/` | Cursor agent config |

### `.agents/skills/`
Shared, agent-agnostic skills. Available to all agents (CC, Cursor, Codex, etc.).
See `AGENT_SKILLS.md` for full inventory.

### `hooks/`
Git hooks (pre-commit: syntax check + device snapshot, pre-push: guard).

### `macos/`
macOS-specific: `defaults.sh`, Ghostty config, LaunchAgents, LaunchDaemons, Defender exclusions.

### `linux/`
Linux-specific: install scripts, security config, Ghostty config, fstab example.

### `wsl/`
WSL-specific: Windows Terminal config.

### `tui/`
Interactive update TUI (`dotfiles --update`): banner, install, status, tools.

### `modules/_lib/`
Shared bash helpers used by all modules.
