# Codebase map

## Entrypoints

| Path | Responsibility |
|---|---|
| `stow.sh` | Preview, apply, and remove a Stow profile |
| `install.sh` | Apply a profile and configure mutable app state |
| `bootstrap.sh` | Compatibility alias for `install.sh` |
| `setup/migrate-links.py` | One-time guarded migration from legacy links |

## Declarative configuration

`stow/<package>/` mirrors `$HOME`. The package list for each machine lives in
`profiles/<name>.stow`.

- `stow/zsh/`: shell entrypoints and tmux
- `stow/git/`: Git configuration and hooks
- `stow/cli/`: small CLI configuration and commands
- `stow/agents/`: shared policies and skills
- `stow/cursor/`: stable Cursor agents, hooks, and rules
- `stow/pi/`: stable Pi config, extensions, hooks, prompts, and shim
- `stow/zed/`: stable Zed files
- `stow/desktop/`, `stow/macos/`, `stow/linux/`: environment overlays

## Imperative setup

- `setup/pi.sh` and `setup/pi/settings.py`: merge runtime settings and model policy
- `setup/cursor.sh`: patch mutable hooks and copy files across WSL boundaries
- `setup/zed.sh`: merge mutable settings and copy files across WSL boundaries
- `setup/paseo.sh`: synchronize and register plugins without linking `~/.paseo`
- `scripts/install/`: focused package and machine setup scripts

## Source-only material

- `sources/paseo/`: tracked Paseo plugin source and manifest
- `zsh/`: shell modules loaded by `stow/zsh/.zshrc`
- `scripts/`: maintenance utilities not installed automatically
- `infra/`: fleet documentation

## Boundaries

Do not add another generic module system. New static configuration belongs in a
Stow package. New generated or machine-mutating behavior belongs in one named
setup script. Runtime state and secrets stay outside the repository.
