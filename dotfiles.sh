#!/usr/bin/env bash
# Require bash 4+ (we use declare -g, associative arrays, multi-pattern case).
# macOS ships bash 3.2, so re-exec under Homebrew bash if available.
if (( BASH_VERSINFO[0] < 4 )); then
    for _candidate in /opt/homebrew/bin/bash /usr/local/bin/bash /home/linuxbrew/.linuxbrew/bin/bash; do
        if [[ -x "$_candidate" ]]; then
            exec "$_candidate" "$0" "$@"
        fi
    done
    echo "Error: bash 4+ required, found $BASH_VERSION. Install: brew install bash" >&2
    exit 1
fi
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

# --- gum detection ---
# Cross-platform: download static binary from GitHub releases via curl.
# No sudo, no package manager, no snap. Works on macOS + Linux (x86_64/arm64).
GUM_VERSION="${GUM_VERSION:-0.14.5}"
ensure_gum() {
    command -v gum >/dev/null 2>&1 && return 0
    echo "gum not found — installing static binary from GitHub releases…"

    local os arch
    case "$(uname -s)" in
        Darwin) os="Darwin" ;;
        Linux)  os="Linux" ;;
        *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64)   arch="x86_64" ;;
        arm64|aarch64)  arch="arm64" ;;
        *) echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;;
    esac

    if ! command -v curl >/dev/null 2>&1; then
        echo "curl is required to install gum. Install curl and retry." >&2
        exit 1
    fi

    local url="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_${os}_${arch}.tar.gz"
    local bindir="$HOME/.local/bin"
    local tmp
    tmp="$(mktemp -d)"
    mkdir -p "$bindir"

    if ! curl -fsSL "$url" | tar -xz -C "$tmp"; then
        rm -rf "$tmp"
        echo "Failed to download gum from $url" >&2
        exit 1
    fi

    local src
    src="$(find "$tmp" -type f -name gum | head -1)"
    if [[ -z "$src" ]]; then
        rm -rf "$tmp"
        echo "gum binary not found in archive" >&2
        exit 1
    fi

    install -m 755 "$src" "$bindir/gum"
    rm -rf "$tmp"

    case ":$PATH:" in
        *":$bindir:"*) ;;
        *) export PATH="$bindir:$PATH" ;;
    esac

    if ! command -v gum >/dev/null 2>&1; then
        echo "gum install failed (binary not on PATH after install to $bindir)" >&2
        exit 1
    fi
    echo "gum v${GUM_VERSION} installed to $bindir/gum"
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
        *Devices*)   cat <<EOF

  Devices
  ───────
  Cross-device inventory of Claude config state.
  Each machine writes .claude/devices/<host>.json on update.

  Shows: enabled plugins, MCP servers, skills per host.

  Equivalent CLI:
    scripts/claude/device-snapshot.sh write
    scripts/claude/device-snapshot.sh list
    scripts/claude/device-snapshot.sh show <host>
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
        *Reset*)     cat <<EOF

  Reset
  ─────
  Remove dotfiles-owned state: symlinks pointing into \$DOTFILES_DIR,
  registered MCP servers, installed Claude plugins. Third-party files
  are never touched. Backups (\\*.backup.\\*) are restored if found.

  Multi-select per module. Dry-run is offered before execute.

  Equivalent CLI:
    bootstrap.sh --reset [--dry-run]
    bootstrap.sh --reset=mod1,mod2
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
        "  Devices"
        "  Doctor"
        "  Reset"
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
            if   [[ "$cat" == "core"     ]]; then prio=1
            elif [[ "$cat" == "shell"    ]]; then prio=2
            elif [[ "$cat" == "claude"   ]]; then prio=3
            elif [[ "$cat" == "editor"   ]]; then prio=4
            elif [[ "$cat" == "gui"      ]]; then prio=5
            elif [[ "$cat" == "tools"    ]]; then prio=6
            elif [[ "$cat" == "optional" ]]; then prio=7
            else prio=9
            fi
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
                [[ -z "${DOTFILES_NONINTERACTIVE:-}" ]] && { read -rsp "Press any key…" -n1; echo; }
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
    [[ -z "${DOTFILES_NONINTERACTIVE:-}" ]] && { read -rsp "Press any key…" -n1; echo; }
}

screen_devices() {
    clear
    render_banner
    render_subtitle "Devices"
    bash "$DOTFILES_DIR/scripts/claude/device-snapshot.sh" list
    echo
    if gum confirm "Refresh this device's snapshot now?"; then
        bash "$DOTFILES_DIR/scripts/claude/device-snapshot.sh" write
    fi
    echo
    [[ -z "${DOTFILES_NONINTERACTIVE:-}" ]] && { read -rsp "Press any key…" -n1; echo; }
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
    [[ -z "${DOTFILES_NONINTERACTIVE:-}" ]] && { read -rsp "Press any key…" -n1; echo; }
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

screen_reset() {
    clear
    render_banner
    render_subtitle "Reset"
    run_reset
}

# --- Main ---

main() {
    ensure_gum
    source "$DOTFILES_DIR/tui/banner.sh"
    source "$DOTFILES_DIR/tui/status.sh"
    source "$DOTFILES_DIR/tui/update.sh"
    source "$DOTFILES_DIR/tui/install.sh"
    source "$DOTFILES_DIR/tui/reset.sh"

    # Direct mode flags — non-interactive (no gum choose / read prompts)
    case "${1:-}" in
        --update)        DOTFILES_NONINTERACTIVE=1 run_update;  return ;;
        --install)       DOTFILES_NONINTERACTIVE=1 run_install; return ;;
        --reset)         run_reset;   return ;;
        --doctor)        bash "$DOTFILES_DIR/scripts/doctor.sh" "${@:2}"; return ;;
        --claude-doctor) bash "$DOTFILES_DIR/modules/claude-settings/doctor.sh" "${@:2}"; return ;;
        --status)        show_status; return ;;
        --devices)       bash "$DOTFILES_DIR/scripts/claude/device-snapshot.sh" list; return ;;
    esac

    local _menu_tmp
    _menu_tmp="$(mktemp)"
    while true; do
        clear
        render_banner
        local action=""
        main_menu > "$_menu_tmp" 2>/dev/null || { rm -f "$_menu_tmp"; break; }
        action="$(<"$_menu_tmp")"
        [[ -z "$action" ]] && { rm -f "$_menu_tmp"; break; }

        case "$action" in
            *Install*) screen_install ;;
            *Update*)  screen_update ;;
            *Modules*) screen_modules ;;
            *Status*)  screen_status ;;
            *Devices*) screen_devices ;;
            *Doctor*)  screen_doctor ;;
            *Reset*)   screen_reset ;;
            *Quit*|"") break ;;
        esac
    done
    rm -f "$_menu_tmp" 2>/dev/null || true

    clear
    gum style --align center --foreground 220 --margin "1 2" "bye"
}

main "$@"
