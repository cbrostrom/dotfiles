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
        [[ "$ans" =~ ^[Yy]$ ]] && brew install gum && return 0
    elif [[ -f /etc/debian_version ]]; then
        echo "Install via: sudo apt install gum"
        read -rp "Auto-install now? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] && sudo apt install -y gum && return 0
    fi
    echo "Please install gum and re-run. Exiting."
    exit 1
}

# Used by fzf --preview to show contextual help for each top-level action.
# Called as: dotfiles.sh --preview-action "<label>"
if [[ "${1:-}" == "--preview-action" ]]; then
    case "${2:-}" in
        *Install*)   cat <<EOF

  Install / Setup
  ───────────────
  Pick modules to install on this machine via a checkbox UI.
  Already-installed modules re-run idempotently — safe to repeat.

  Equivalent CLI:
    bootstrap.sh                 (full install)
    bootstrap.sh --only=foo,bar  (subset)
EOF
            ;;
        *Update*)    cat <<EOF

  Update
  ──────
  git pull --rebase --autostash, then re-run every enabled module.

  Equivalent CLI:
    bootstrap.sh --update
EOF
            ;;
        *Modules*)   cat <<EOF

  Modules
  ───────
  Browse the module registry. Filter by typing.
  Each pick offers Run / Preview (--diff) / Info.

  Eligible modules only — platform-incompatible ones are hidden.

  Equivalent CLI:
    bootstrap.sh --list
    bootstrap.sh --info=NAME
    bootstrap.sh --diff=NAME
EOF
            ;;
        *Status*)    cat <<EOF

  Status
  ──────
  Full health report:
    • Symlink integrity
    • Git config / signing setup
    • Local secrets file + permissions
    • Per-module status table (clean / dirty / unknown / N/A)
EOF
            ;;
        *Doctor*)    cat <<EOF

  Doctor
  ──────
  Diagnose drift and broken state. Optionally apply fixes.

  Equivalent CLI:
    scripts/doctor.sh
    scripts/doctor.sh --fix
EOF
            ;;
        *Quit*)      cat <<EOF

  Quit
  ────
  Exit the TUI.
EOF
            ;;
        *) echo "" ;;
    esac
    exit 0
fi

# Used by fzf --preview to show module info for the modules menu.
# Called as: dotfiles.sh --preview-module "<row>"
if [[ "${1:-}" == "--preview-module" ]]; then
    line="${2:-}"
    name="$(echo "$line" | awk -F' · ' '{print $2}' | tr -d ' ')"
    [[ -z "$name" ]] && exit 0
    bash "$DOTFILES_DIR/bootstrap.sh" "--info=$name" 2>/dev/null
    exit 0
fi

# --- Action / module menus ---

main_menu() {
    local actions=(
        "  Install / Setup"
        "  Update"
        "  Modules"
        "  Status"
        "  Doctor"
        "  Quit"
    )
    printf "%s\n" "${actions[@]}" | fzf \
        --height=14 --layout=reverse --border rounded \
        --border-label=" dotfiles " \
        --border-label-pos=3 \
        --color='border:8,prompt:220,pointer:220,marker:220,info:8,header:8' \
        --pointer='▸' --prompt='› ' \
        --preview-window='right:60%:wrap' \
        --preview="bash '$DOTFILES_DIR/dotfiles.sh' --preview-action {}" \
        --header='use ↑↓ to navigate · enter to select · esc to quit'
}

modules_menu() {
    local -a entries=()
    local name action label

    DOTFILES_QUIET=1 modules_init >/dev/null 2>&1 || return
    DOTFILES_QUIET=1 modules_discover >/dev/null 2>&1 || return

    while IFS= read -r name; do
        action="$(_decide_module_action "$name")"
        case "$action" in
            run|skip-disabled|skip-not-selected|skip-missing-req:*)
                # category · name · description
                label="$(printf '%-9s · %-18s · %s' \
                    "${_MODULES_CATEGORY[$name]}" "$name" "${_MODULES_DESC[$name]}")"
                entries+=("$label")
                ;;
        esac
    done < <(
        for n in "${_MODULES_REGISTRY[@]}"; do
            cat="${_MODULES_CATEGORY[$n]:-optional}"
            case "$cat" in
                core) prio=1 ;; shell) prio=2 ;; claude) prio=3 ;;
                editor) prio=4 ;; gui) prio=5 ;; tools) prio=6 ;;
                optional) prio=7 ;; *) prio=9 ;;
            esac
            printf "%d %s\n" "$prio" "$n"
        done | sort -k1n -k2 | awk '{print $2}'
    )

    entries+=("← Back")

    printf "%s\n" "${entries[@]}" | fzf \
        --height=22 --layout=reverse --border rounded \
        --border-label=" modules " \
        --border-label-pos=3 \
        --color='border:8,prompt:220,pointer:220,marker:220,info:8,header:8' \
        --pointer='▸' --prompt='module › ' \
        --preview-window='right:55%:wrap' \
        --preview="bash '$DOTFILES_DIR/dotfiles.sh' --preview-module {}" \
        --header='filter by typing · enter to select'
}

action_for_module() {
    local module_name="$1"
    printf "Run\nPreview (--diff)\nInfo\nCancel" | fzf \
        --height=10 --layout=reverse --border rounded \
        --border-label=" $module_name " \
        --border-label-pos=3 \
        --color='border:8,prompt:220,pointer:220,marker:220' \
        --pointer='▸' --prompt='› ' \
        --no-preview
}

# --- Screens ---

screen_modules() {
    while true; do
        clear
        render_banner
        render_subtitle "Modules"
        local pick module_name action
        pick="$(modules_menu)" || return
        [[ "$pick" == "← Back" || -z "$pick" ]] && return
        module_name="$(echo "$pick" | awk -F' · ' '{print $2}' | tr -d ' ')"
        [[ -z "$module_name" ]] && return

        clear
        render_banner
        render_subtitle "$module_name"
        action="$(action_for_module "$module_name")" || continue

        case "$action" in
            Run)
                clear; render_banner; render_subtitle "$module_name — running"
                if gum spin --title "running $module_name" -- \
                       bash "$DOTFILES_DIR/bootstrap.sh" "--only=$module_name"; then
                    gum style --align center --foreground 10 --bold "✓ $module_name complete"
                else
                    gum style --align center --foreground 9 --bold "✗ $module_name failed"
                fi
                echo
                read -rsp "Press any key…" -n1; echo
                ;;
            "Preview (--diff)")
                clear
                bash "$DOTFILES_DIR/bootstrap.sh" "--diff=$module_name" 2>&1 | less -R
                ;;
            Info)
                clear
                bash "$DOTFILES_DIR/bootstrap.sh" "--info=$module_name" 2>&1 | less -R
                ;;
            Cancel|"") ;;
        esac
    done
}

screen_status() {
    clear
    render_banner
    render_subtitle "Status"
    show_status
    bash "$DOTFILES_DIR/bootstrap.sh" --list
    echo
    read -rsp "Press any key…" -n1; echo
}

screen_doctor() {
    clear
    render_banner
    render_subtitle "Doctor"
    if gum confirm "Run with --fix to apply auto-repairs?"; then
        bash "$DOTFILES_DIR/scripts/doctor.sh" --fix
    else
        bash "$DOTFILES_DIR/scripts/doctor.sh"
    fi
    echo
    read -rsp "Press any key…" -n1; echo
}

screen_install() {
    clear
    render_banner
    render_subtitle "Install / Setup"
    run_install
}

screen_update() {
    clear
    render_banner
    render_subtitle "Update"
    run_update
}

# --- Main ---

main() {
    ensure_gum
    source "$DOTFILES_DIR/tui/banner.sh"
    source "$DOTFILES_DIR/tui/status.sh"
    source "$DOTFILES_DIR/tui/update.sh"
    source "$DOTFILES_DIR/tui/install.sh"

    # Direct mode flags
    case "${1:-}" in
        --update)  run_update;  return ;;
        --install) run_install; return ;;
        --doctor)  bash "$DOTFILES_DIR/scripts/doctor.sh"; return ;;
        --status)  show_status; return ;;
    esac

    while true; do
        clear
        render_banner
        local action
        action="$(main_menu)" || break

        case "$action" in
            *Install*) screen_install ;;
            *Update*)  screen_update ;;
            *Modules*) screen_modules ;;
            *Status*)  screen_status ;;
            *Doctor*)  screen_doctor ;;
            *Quit*|"") break ;;
        esac
    done

    clear
    gum style --align center --foreground 220 --margin "1 2" "bye"
}

main "$@"
