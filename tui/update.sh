#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

run_update() {
    echo
    gum style --bold --foreground 220 "UPDATE"
    echo

    local failed=()

    _spin() {
        local title="$1"; shift
        if gum spin --title "$title" -- "$@"; then
            gum style --foreground 10 "  ✓ $title"
        else
            gum style --foreground 9  "  ✗ $title"
            failed+=("$title")
        fi
    }

    _spin "Pulling latest from git" \
        git -C "$DOTFILES_DIR" pull --rebase --autostash
    gum style --foreground 8 "    zsh, git, scripts, dotfiles"

    _spin "Updating symlinks" \
        bash "$DOTFILES_DIR/scripts/install/symlinks.sh"
    gum style --foreground 8 "    ~/.zshrc, ~/.gitconfig, ~/.zshenv og øvrige dotfiler"

    _spin "Syncing Zed config" \
        bash "$DOTFILES_DIR/scripts/zed/install-zed-config.sh"
    gum style --foreground 8 "    settings.json (base→local merge), keymap.json, rules, snippets/, themes/"

    local vscodium_script="$DOTFILES_DIR/scripts/vscodium/install-vscodium-config.sh"
    local drift_out
    if drift_out="$(bash "$vscodium_script" --check 2>/dev/null)"; then
        _spin "Syncing VSCodium config" \
            bash "$vscodium_script" --config --yes
        gum style --foreground 8 "    settings.json (base→local merge), keybindings.json, tasks.json"
    else
        gum style --foreground 220 "  ⚠ VSCodium has local edits:"
        while IFS= read -r line; do
            gum style --foreground 8 "    $line"
        done <<< "$drift_out"
        local choice
        choice="$(gum choose --header "Action?" \
            "Merge (union, local wins on tie)" \
            "Overwrite (use dotfiles)" \
            "Skip (keep local)")"
        case "$choice" in
            "Merge"*)
                _spin "Merging VSCodium config" \
                    bash "$vscodium_script" --merge --yes
                gum style --foreground 8 "    settings.json (base→local), keybindings.json + tasks.json (union)"
                ;;
            "Overwrite"*)
                _spin "Syncing VSCodium config" \
                    bash "$vscodium_script" --config --yes
                gum style --foreground 8 "    settings.json (base→local merge), keybindings.json, tasks.json"
                ;;
            *)
                gum style --foreground 8 "  ⊘ Syncing VSCodium config (skipped — local edits preserved)"
                ;;
        esac
    fi

    _spin "Syncing Claude config" \
        bash "$DOTFILES_DIR/scripts/claude/install-claude-config.sh"
    gum style --foreground 8 "    settings.json (base→local merge), CLAUDE.md, RTK.md, hooks"

    _spin "Upgrading Python MCP tools" \
        bash -c 'pipx upgrade mcp-atlassian >/dev/null 2>&1 || true'
    gum style --foreground 8 "    mcp-atlassian"

    _spin "Registering MCP servers" \
        bash "$DOTFILES_DIR/bootstrap.sh" --mcp-only
    gum style --foreground 8 "    github, shopify-dev, engram-personal/work, atlassian-fiskars/akqa, …"

    echo
    gum style --foreground 8 "  Running doctor…"
    if bash "$DOTFILES_DIR/scripts/doctor.sh"; then
        gum style --foreground 10 "  ✓ Running doctor"
    else
        gum style --foreground 9  "  ✗ Running doctor"
        failed+=("Running doctor")
    fi

    echo
    if [[ ${#failed[@]} -eq 0 ]]; then
        gum style --foreground 10 --bold "All done."
    else
        gum style --foreground 9 --bold "Completed with issues:"
        for f in "${failed[@]}"; do
            gum style --foreground 9 "  • $f"
        done
    fi
    echo
    read -rsp "Press any key to return…" -n1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_update
fi
