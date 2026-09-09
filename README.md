# Dotfiles

Cross-platform dotfiles for macOS, Linux (Debian/Ubuntu), and WSL2. Provisioned
via a module system: each piece of setup (symlinks, fonts, Cursor/Pi config,
MCP servers, etc.) is a self-contained module under `modules/`.

## Structure

```
~/dotfiles/
├── bootstrap.sh                  # Module-driven entrypoint
├── modules/                      # Module system + individual modules
│   ├── _lib/                       # loader, log, platform, config helpers
│   ├── packages/  symlinks/  fonts/  zsh/  rust-tools/  …
│   └── README.md                   # How to add a module
├── modules.conf                  # Repo-wide module defaults
├── modules.conf.example          # Template for per-machine overrides
├── .zshrc, .gitconfig, .gitignore_global   # Core dotfiles
├── zsh/                          # Modular zsh config (00-09)
├── .config/                      # bat, lazygit, procs, starship, cursor, zed…
├── macos/ghostty/                # Ghostty terminal (macOS)
├── linux/ghostty/                # Ghostty terminal (native Linux)
├── wsl/windows-terminal/         # Windows Terminal settings (WSL)
├── scripts/                      # Implementation scripts (called by modules)
├── tui/                          # gum-based interactive front-end
└── .local-config.example         # Machine-specific config template
```

## Installation

```bash
git clone https://github.com/yourusername/dotfiles ~/dotfiles
cd ~/dotfiles
./bootstrap.sh                        # full install — discovers + runs all enabled modules
./bootstrap.sh --list                 # see modules and their state on this machine
./bootstrap.sh --only=symlinks,zsh    # run a subset
./bootstrap.sh --skip=fonts           # opt out of one
./bootstrap.sh --update               # git pull + re-run all enabled
```

Per-machine module overrides: `~/.config/dotfiles/modules.conf` (auto-created
from `modules.conf.example` on first `bootstrap.sh` run). One module name per
line; prefix `!` to disable.

See `modules/README.md` for module authoring details.

## Usage

- `dotfiles` – Interactive TUI (requires `gum`)
- `./bootstrap.sh --list` – Module status table
- `./bootstrap.sh --update` – Refresh after `git pull`
- `./scripts/doctor.sh` – Health check
- `./uninstall.sh` – Remove symlinks, restore backups

## Fleet

Multi-host topology for agents: [`infra/fleet.md`](infra/fleet.md) (markdown) · [`infra/infra.html`](infra/infra.html) (browser). SSH source of truth: `config/fleet-hosts.conf`.

## Profiles

| Profile | Machines | Notes |
|---------|----------|-------|
| `desktop-full` | Mac | Full GUI + dev stack |
| `server-headless` | LinuxBro, SuperBro | No GUI, lean agent set |
| `wsl` | MonsterBro | TUI + Windows interop |

## Platforms

| Platform | Terminal | Notes |
|----------|----------|-------|
| **macOS** | Ghostty | Config in `macos/ghostty/` |
| **Linux** | Ghostty | Config in `linux/ghostty/`; Debian/Ubuntu (apt) |
| **WSL** | Windows Terminal | Ghostty skipped; settings in `wsl/windows-terminal/` |

## Key Components

- **zsh** – Modular config with direct-source plugins (no plugin manager), starship, fzf, zoxide
- **Pi** – Daily-driver agent config under `.config/pi/` via `modules/pi`
- **Cursor** – Rules, hooks, skills in `.cursor/`
- **Higgins** – Vault CLI (`higgins`); vault at `~/Vaults/Higgins/AI`
- **.local-config** – Machine-specific (git-ignored); copy from `.local-config.example`

## Troubleshooting

### SSH commit signing ("gpg failed to sign")

`commit.gpgsign=true` with `gpg.format=ssh` — git invokes `ssh-keygen -Y sign` which reads
the private key directly and prompts for passphrase non-interactively → fails silently → generic "gpg failed".

Fix: use the **public key file** as the signingkey. Git then uses ssh-agent automatically:

```ini
[user]
    signingkey = ~/.ssh/github.pub   # NOT ~/.ssh/github
[gpg]
    format = ssh
[gpg "ssh"]
    allowedSignersFile = ~/.config/git/allowed_signers
```

Verify with `/opt/homebrew/bin/git log --show-signature -1`.
