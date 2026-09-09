# Codebase map — dotfiles

Read this before searching. Jump directly to the right file.

## Root

| File | Purpose |
|------|---------|
| `AGENTS.md` | AI agent policy, approval gate, Higgins protocol, push guard |
| `AGENT_SKILLS.md` | Skill inventory for all agents |
| `CODEBASE.md` | This file — directory/file index |
| `Brewfile` | macOS Homebrew packages |
| `install.sh` | Bootstrap entry point |
| `dotfiles.sh` | Main CLI (`dotfiles --update`, `dotfiles --status`) |
| `modules.conf` | Repo-wide module defaults (read by bootstrap before per-host config) |
| `modules.conf.example` | Template for `~/.config/dotfiles/modules.conf` (per-host overrides) |
| `VERSION` | Current dotfiles version |

## Key directories

### `modules/`
Install units. Each module has `install.sh` + optional `doctor.sh`.

| Module | Purpose |
|--------|---------|
| `skills/` | Agent skill installation (`~/.agents/skills/`, `~/.cursor/skills`) |
| `symlinks/` | Dotfile symlink definitions |
| `zsh/` | Zsh config module |
| `packages/` | Cross-platform package install |
| `starship/` | Starship prompt config |
| `herdr/` | Herdr terminal multiplexer — opt-in per-host |
| `pi/` | PI coding agent daily-driver — opt-in per-host |
| `opencode/` | OpenCode config symlink — opt-in |
| `rbw/` | Bitwarden CLI secrets — opt-in |
| `_lib/` | Shared module helpers |

### `zsh/`
Numbered zsh config files sourced in order:

| File | Purpose |
|------|---------|
| `00-performance.zsh` | Profiling / lazy loading |
| `01-environment.zsh` | `PATH`, env vars |
| `02-plugins.zsh` | Direct-source plugins |
| `03-aliases.zsh` | Shell aliases |
| `04-functions.zsh` | Shell functions |
| `05-integrations.zsh` | Tool integrations (fzf, zoxide, etc.) |
| `06-autoupdate.zsh` | Autoupdate logic |
| `08-workflow.zsh` | Workflow switches |
| `09-herdr.zsh` / `09-cmux.zsh` | Multiplexer integrations |
| `lib/` | Shared zsh helpers |

### `scripts/`
Standalone tools and install helpers.

| Script | Purpose |
|--------|---------|
| `doctor.sh` | Dotfiles health check |
| `janitor.sh` | Vault / session maintenance |
| `ob` | Obsidian REST API CLI |
| `pi` | PI coding agent shim |
| `rtk/` | Token-compression rewrite policy |
| `cursor/` | Cursor-specific helpers |
| `install/` | Symlink and package installers |
| `vault/` | Vault helpers |
| `zsh/` | Zsh helpers |

### `.cursor/`
Cursor IDE config: `rules/`, `hooks/`, `agents/`.

### `.config/pi/`
PI agent config: extensions, hooks, settings layers, prompts.

### `.agents/skills/`
Shared, agent-agnostic skills. See `AGENT_SKILLS.md`.

### `higgins/`
Higgins vault tooling (janitor, etc.). Durable brain is `~/Vaults/Higgins/AI`.

### `hooks/`
Git hooks (pre-commit, pre-push).

### `macos/` / `linux/` / `wsl/`
Platform-specific Ghostty / defaults / Windows Terminal.

### `tui/`
Interactive `dotfiles` CLI screens (gum): banner, install, status, update, reset.
