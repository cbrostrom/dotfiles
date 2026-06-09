#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

_vscodium_user_dir() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        local win_user="${USERNAME:-$(whoami)}"
        echo "/mnt/c/Users/$win_user/AppData/Roaming/VSCodium/User"
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        echo "$HOME/Library/Application Support/VSCodium/User"
    else
        echo "$HOME/.config/VSCodium/User"
    fi
}

run_vscodium_tools() {
    local DEST
    DEST="$(_vscodium_user_dir)"

    ACTION=$(printf "Sync config to VSCodium\nInstall extensions\nSync + install extensions\nShow diff\n← Back" | fzf \
        --height=10 --layout=reverse --border \
        --prompt='vscodium › ' \
        --no-preview) || return

    case "$ACTION" in
        "Sync config to VSCodium")
            echo
            bash "$DOTFILES_DIR/scripts/vscodium/install-vscodium-config.sh" --config
            echo
            [[ -t 0 ]] && { read -rsp "Press any key…" -n1; echo; }
            ;;
        "Install extensions")
            echo
            bash "$DOTFILES_DIR/scripts/vscodium/install-vscodium-config.sh" --install-extensions
            echo
            [[ -t 0 ]] && { read -rsp "Press any key…" -n1; echo; }
            ;;
        "Sync + install extensions")
            echo
            bash "$DOTFILES_DIR/scripts/vscodium/install-vscodium-config.sh" --all
            echo
            [[ -t 0 ]] && { read -rsp "Press any key…" -n1; echo; }
            ;;
        "Show diff")
            echo
            local src="$DOTFILES_DIR/.config/vscodium"
            for f in keybindings.json tasks.json; do
                if [[ -f "$src/$f" && -f "$DEST/$f" ]]; then
                    echo "--- $f ---"
                    diff "$src/$f" "$DEST/$f" || true
                fi
            done
            echo
            [[ -t 0 ]] && { read -rsp "Press any key…" -n1; echo; }
            ;;
        "← Back"|"") return ;;
    esac
}

run_vscodium_tools
