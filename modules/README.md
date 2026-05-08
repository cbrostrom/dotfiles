# modules — dotfiles module system

Each subdirectory here is a self-contained dotfiles module: a small bundle of
metadata + scripts that the bootstrap runner discovers, filters, orders by
dependency, and runs.

## Why

The previous `bootstrap.sh` was a 350-line file with platform guards scattered
through every install function. Adding a module meant editing the orchestrator;
disabling one on a specific machine meant grepping for skip conditions.

This system replaces it with discoverable, opt-in/out modules:

- A module is a directory. No central registration.
- Modules declare which platforms / profiles they support — the runner skips
  them with a clear reason if the current machine doesn't match.
- Modules can declare dependencies on other modules; the runner resolves them.
- The user can enable / disable modules via `~/.config/dotfiles/modules.conf`,
  the `DOTFILES_DISABLED` / `DOTFILES_ENABLED` env vars, or the `--only` /
  `--skip` CLI flags.

## Layout

```
modules/
  _lib/                  module-system internals (loader, log, platform, config)
  <name>/
    module.sh            REQUIRED  manifest (sourced bash)
    install.sh           REQUIRED  install / configure logic (idempotent)
    update.sh            optional  re-run friendly variant; defaults to install.sh
    status.sh            optional  exit 0 if installed/healthy, 1 if needs install
    diff.sh              optional  preview what install.sh would do (--diff fallback prints install.sh source)
    uninstall.sh         optional  cleanup
```

The runner enters each `install.sh` with `DOTFILES_DIR`, `MODULE_DIR`, and
`MODULE_NAME` exported; the working directory is set to `$DOTFILES_DIR`.

## module.sh manifest

```bash
#!/usr/bin/env bash
MODULE_NAME="vscodium"                      # must match directory name
MODULE_DESC="VSCodium settings + extensions"
MODULE_CATEGORY="editor"                    # core|shell|claude|editor|gui|tools|optional
MODULE_PLATFORMS="macos linux wsl"          # default: all
MODULE_PROFILES="desktop-full wsl"          # default: all
MODULE_CORE=false                           # default: false
MODULE_DEPENDS="symlinks"                   # space-separated module names
MODULE_REQUIRES="jq python3"                # space-separated commands
MODULE_DEFAULT_ENABLED=true                 # default: true
```

| Field                     | Purpose                                                              |
|---------------------------|----------------------------------------------------------------------|
| `MODULE_NAME`             | Identifier; must match directory name                                |
| `MODULE_DESC`             | One-line description shown in `--list`                               |
| `MODULE_CATEGORY`         | Group label used by `--list` and the TUI tools menu                   |
| `MODULE_PLATFORMS`        | `macos`, `linux`, `wsl`, or `all`. Empty = all.                       |
| `MODULE_PROFILES`         | `desktop-full`, `server-headless`, `wsl`, or `all`. Empty = all.       |
| `MODULE_CORE`             | If `true`, disabling triggers a warning (still respected).           |
| `MODULE_DEPENDS`          | Other modules that must run first.                                    |
| `MODULE_REQUIRES`         | Commands that must be on `PATH` — module skipped (with warn) if not. |
| `MODULE_DEFAULT_ENABLED`  | If `false`, module is opt-in (user must explicitly enable).           |

## User configuration

`~/.config/dotfiles/modules.conf`:

```
# one module name per line
# prefix '!' to disable (overrides MODULE_DEFAULT_ENABLED=true)
# bare name explicitly enables (overrides MODULE_DEFAULT_ENABLED=false)

beets                # opt-in module — enable on this machine
!fonts               # disable fonts even though they'd default-on
```

CLI / env precedence (later wins):
1. `MODULE_DEFAULT_ENABLED`
2. `~/.config/dotfiles/modules.conf`
3. env: `DOTFILES_DISABLED="m1,m2"` / `DOTFILES_ENABLED="m1,m2"`
4. CLI: `bootstrap.sh --skip=m1,m2` / `--only=m1,m2`

`--only` is absolute: only the listed modules (and their topo deps) run.

## Common commands

```bash
./bootstrap.sh                     # full install (everything enabled+eligible)
./bootstrap.sh --update            # git pull + run all enabled
./bootstrap.sh --list              # human-readable status table (grouped by category, colored)
./bootstrap.sh --info=fonts        # detail view: deps, status, last-run, hints
./bootstrap.sh --diff=symlinks     # preview what the module would do (or print install.sh)
./bootstrap.sh --only=fonts,zsh    # run only these (and their deps)
./bootstrap.sh --skip=mcp-servers  # run all except this
./bootstrap.sh --doctor            # diagnostic only
```

## Adding a new module

```bash
mkdir modules/my-module
cat > modules/my-module/module.sh << 'EOF'
#!/usr/bin/env bash
MODULE_NAME="my-module"
MODULE_DESC="What it does"
MODULE_PLATFORMS="all"
MODULE_PROFILES="all"
MODULE_CORE=false
MODULE_DEPENDS=""
MODULE_REQUIRES=""
MODULE_DEFAULT_ENABLED=true
EOF
cat > modules/my-module/install.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
log "doing the thing …"
# … your install logic …
ok "done"
EOF
chmod +x modules/my-module/install.sh
./bootstrap.sh --list   # verify it's discovered
./bootstrap.sh --only=my-module
```

## status.sh — idempotency check

The runner calls `status.sh` (when present) with the module dir as cwd. Exit 0
means installed/healthy; exit 1 means needs install. The runner does not
auto-skip dirty modules during `bootstrap.sh` runs (modules must be idempotent
on their own); `status.sh` is purely informational for `--list`.
