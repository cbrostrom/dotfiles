#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
profile="${1:-}"

if [[ -z "$profile" ]]; then
    case "$(uname -s)" in
        Darwin) profile="macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                profile="wsl"
            else
                profile="linux"
            fi
            ;;
        *)
            printf 'error: pass an explicit profile\n' >&2
            exit 2
            ;;
    esac
fi

"$ROOT/stow.sh" apply "$profile"

# Seed the per-machine git config. Never overwritten once it exists.
if [[ ! -f "$HOME/.gitconfig.local" && -f "$ROOT/.gitconfig.local.example" ]]; then
    cp "$ROOT/.gitconfig.local.example" "$HOME/.gitconfig.local"
    printf '\nseeded: ~/.gitconfig.local from .gitconfig.local.example\n'
    printf '  edit it now: uncomment the GitHub credential helper and, where the\n'
    printf '  signing key exists, the SSH signing block; then run `gh auth login`.\n'
fi

case "$profile" in
    macos)
        if ! command -v brew >/dev/null 2>&1; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
                [[ -x "$b" ]] && eval "$("$b" shellenv)" && break
            done
        fi
        brew bundle install --no-upgrade --file="$ROOT/Brewfile"
        "$ROOT/macos/defaults.sh"
        "$ROOT/scripts/install/launchd.sh"
        HIGGINS_ROLE=write-through "$ROOT/scripts/install/higgins.sh"
        "$ROOT/scripts/install/npm-globals.sh"
        "$ROOT/setup/pi.sh"
        "$ROOT/setup/claude-work.sh"
        "$ROOT/setup/zed.sh"
        "$ROOT/setup/herdr.sh"
        "$ROOT/setup/paseo.sh"
        ;;
    linux | wsl)
        "$ROOT/scripts/install/higgins.sh"
        "$ROOT/scripts/install/rtk.sh"
        "$ROOT/scripts/install/dejavu.sh"
        "$ROOT/scripts/install/npm-globals.sh"
        "$ROOT/scripts/install/fastfetch.sh"
        "$ROOT/setup/pi.sh"
        "$ROOT/setup/zed.sh"
        "$ROOT/setup/herdr.sh"
        "$ROOT/setup/paseo.sh"
        ;;
    cloudbro)
        "$ROOT/scripts/install/higgins.sh"
        "$ROOT/scripts/install/syncthing.sh"
        "$ROOT/scripts/install/rtk.sh"
        "$ROOT/scripts/install/dejavu.sh"
        "$ROOT/scripts/install/npm-globals.sh"
        "$ROOT/scripts/install/fastfetch.sh"
        "$ROOT/setup/pi.sh"
        "$ROOT/setup/herdr.sh"
        "$ROOT/setup/paseo.sh"
        ;;
    server)
        HIGGINS_ROLE=write-through "$ROOT/scripts/install/higgins.sh"
        "$ROOT/scripts/install/syncthing.sh"
        "$ROOT/scripts/install/rtk.sh"
        "$ROOT/scripts/install/dejavu.sh"
        "$ROOT/scripts/install/npm-globals.sh"
        "$ROOT/scripts/install/fastfetch.sh"
        "$ROOT/setup/pi.sh"
        "$ROOT/setup/herdr.sh"
        "$ROOT/setup/paseo.sh"
        ;;
    *)
        printf 'error: unknown profile: %s\n' "$profile" >&2
        exit 2
        ;;
esac

printf 'dotfiles installed with profile: %s\n' "$profile"
