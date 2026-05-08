#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

# --- gum detection ---
ensure_gum() {
    command -v gum >/dev/null 2>&1 && return 0
    echo "gum not found — required for this TUI."
    if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        echo "Install via: brew install gum"
        read -rp "Auto-install now? [y/N] " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            brew install gum && return 0
        fi
    elif [[ -f /etc/debian_version ]]; then
        echo "Install via: sudo apt install gum"
        read -rp "Auto-install now? [y/N] " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            sudo apt install -y gum && return 0
        fi
    fi
    echo "Please install gum and re-run. Exiting."
    exit 1
}

# --- main loop ---
main() {
    ensure_gum
    source "$DOTFILES_DIR/tui/status.sh"
    source "$DOTFILES_DIR/tui/update.sh"
    source "$DOTFILES_DIR/tui/install.sh"

    # Direct mode: dotfiles --update / --install / --doctor
    case "${1:-}" in
        --update)  run_update;  return ;;
        --install) run_install; return ;;
        --doctor)  bash "$DOTFILES_DIR/scripts/doctor.sh"; return ;;
    esac

    local version git_hash
    version="$(cat "$DOTFILES_DIR/VERSION" 2>/dev/null || echo "?")"
    git_hash="$(git -C "$DOTFILES_DIR" rev-parse --short HEAD 2>/dev/null || echo "?")"

    while true; do
        ACTION=$(printf "Install / Setup\nUpdate\nTools\nStatus\nQuit" | fzf \
            --height=10 --layout=reverse --border \
            --prompt='dotfiles › ' \
            --header="v${version} (${git_hash})" \
            --no-preview) || break

        case "$ACTION" in
            "Install / Setup") run_install ;;
            "Update")          run_update ;;
            "Tools")           run_tools ;;
            "Status")          clear; show_status; read -rsp "Press any key…" -n1; echo ;;
            "Quit"|"")         break ;;
        esac
    done
}

run_tools() {
    # Enumerate eligible modules from the registry, sorted by category.
    . "$DOTFILES_DIR/modules/_lib/log.sh"
    . "$DOTFILES_DIR/modules/_lib/platform.sh"
    . "$DOTFILES_DIR/modules/_lib/config.sh"
    . "$DOTFILES_DIR/modules/_lib/loader.sh"
    DOTFILES_QUIET=1 modules_init >/dev/null 2>&1 || return
    DOTFILES_QUIET=1 modules_discover >/dev/null 2>&1 || return

    # Build menu: "<category>: <name> — <desc>" for modules eligible on this machine.
    # Skip platform-incompatible modules (they can't run here anyway).
    local -a entries=()
    local name action label
    while IFS= read -r name; do
        action="$(_decide_module_action "$name")"
        case "$action" in
            run|skip-disabled|skip-not-selected|skip-missing-req:*)
                label="$(printf '%-9s · %-18s · %s' \
                    "${_MODULES_CATEGORY[$name]}" "$name" "${_MODULES_DESC[$name]}")"
                entries+=("$label")
                ;;
        esac
    done < <(
        # Sort by category-order then name.
        for n in "${_MODULES_REGISTRY[@]}"; do
            cat="${_MODULES_CATEGORY[$n]:-optional}"
            case "$cat" in
                core)     prio=1 ;;
                shell)    prio=2 ;;
                claude)   prio=3 ;;
                editor)   prio=4 ;;
                gui)      prio=5 ;;
                tools)    prio=6 ;;
                optional) prio=7 ;;
                *)        prio=9 ;;
            esac
            printf "%d %s\n" "$prio" "$n"
        done | sort -k1n -k2 | awk '{print $2}'
    )

    entries+=("← Back")

    local pick
    pick=$(printf "%s\n" "${entries[@]}" | fzf \
        --height=20 --layout=reverse --border \
        --prompt='tools › ' \
        --header='select a module to run (filter by typing)' \
        --no-preview) || return

    [[ "$pick" == "← Back" || -z "$pick" ]] && return

    # Extract module name from "category : name : desc"
    local module_name
    module_name="$(echo "$pick" | awk -F' · ' '{print $2}' | tr -d ' ')"

    [[ -z "$module_name" ]] && return

    # Show preview / confirm / run sequence
    local action
    action=$(printf "Run\nPreview (--diff)\nInfo\nCancel" | fzf \
        --height=8 --layout=reverse --border \
        --prompt="$module_name › " \
        --no-preview) || return

    case "$action" in
        Run)
            gum spin --title "Running $module_name" -- \
                bash "$DOTFILES_DIR/bootstrap.sh" "--only=$module_name" \
                && gum style --foreground 10 "  ✓ $module_name complete" \
                || gum style --foreground 9  "  ✗ $module_name failed"
            read -rsp "Press any key…" -n1; echo ;;
        "Preview (--diff)")
            bash "$DOTFILES_DIR/bootstrap.sh" "--diff=$module_name" 2>&1 | less -R
            ;;
        Info)
            bash "$DOTFILES_DIR/bootstrap.sh" "--info=$module_name" 2>&1 | less -R
            ;;
        Cancel|"") return ;;
    esac
}

main "$@"
