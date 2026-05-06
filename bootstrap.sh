#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — single entrypoint for provisioning a machine from dotfiles
# =============================================================================
# Idempotent. Detects OS + profile, installs packages, creates symlinks,
# verifies result. Designed to be safe to re-run.
#
# Usage:
#   ./bootstrap.sh                  # full bootstrap (detect everything)
#   ./bootstrap.sh --link-only      # only (re)create symlinks
#   ./bootstrap.sh --packages-only  # only install packages
#   ./bootstrap.sh --doctor         # diagnostic only, no changes
#   ./bootstrap.sh --update         # git pull + re-run packages/symlinks/fonts (skip macOS defaults)
#   ./bootstrap.sh --profile=server-headless   # override profile
#
# Profiles:
#   desktop-full    — mac, linuxbro (GUI tools, fonts)
#   server-headless — superbro VPS  (no GUI, security stack)
#   wsl             — WSL2 on monsterbro (TUI + Windows interop)
# =============================================================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

# Make Homebrew available in this script's PATH (script runs as plain bash)
for _brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [[ -x "$_brew_bin" ]]; then
        eval "$("$_brew_bin" shellenv)"
        break
    fi
done
unset _brew_bin

# Source platform helpers (zsh-flavored, but compatible bash subset)
# We re-implement minimally here since bootstrap.sh runs under bash.
is_macos()  { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux()  { [[ "$(uname -s)" == "Linux"  ]]; }
is_wsl()    { is_linux && { [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; }; }
is_debian() { is_linux && [[ -f /etc/debian_version ]]; }
has() { command -v "$1" >/dev/null 2>&1; }

# Color output
if [[ -t 1 ]]; then
    BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
    BLUE=''; GREEN=''; YELLOW=''; RED=''; NC=''
fi
log()    { printf "${BLUE}[bootstrap]${NC} %s\n" "$*"; }
ok()     { printf "${GREEN}[ ok ]${NC} %s\n" "$*"; }
warn()   { printf "${YELLOW}[warn]${NC} %s\n" "$*"; }
err()    { printf "${RED}[err ]${NC} %s\n" "$*" >&2; }

# -----------------------------------------------------------------------------
# Profile detection
# -----------------------------------------------------------------------------
detect_profile() {
    local p=""
    for arg in "$@"; do
        case "$arg" in
            --profile=*) p="${arg#--profile=}";;
        esac
    done
    if [[ -z "$p" && -n "${PROFILE:-}" ]]; then p="$PROFILE"; fi
    if [[ -z "$p" && -f "$HOME/.local-config" ]]; then
        p="$(grep -E '^PROFILE=' "$HOME/.local-config" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"' | tr -d "'")"
    fi
    if [[ -z "$p" ]]; then
        if is_wsl; then p="wsl"
        elif is_macos; then p="desktop-full"
        elif [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then p="server-headless"
        else p="desktop-full"
        fi
    fi
    echo "$p"
}

# -----------------------------------------------------------------------------
# Package install
# -----------------------------------------------------------------------------
install_packages() {
    local profile="$1"
    if is_macos; then
        if ! has brew; then
            warn "Homebrew not installed. Install from https://brew.sh, then re-run."
            return 1
        fi
        if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
            log "brew bundle install …"
            brew bundle --file="$DOTFILES_DIR/Brewfile" install
        fi
    elif is_debian; then
        bash "$DOTFILES_DIR/scripts/install/debian.sh" "$profile"
    else
        warn "Unknown OS — skipping package install. Run distro installer manually."
    fi
}

install_python_tools() {
    if ! command -v pipx >/dev/null 2>&1; then
        warn "pipx not found — skipping Python tool installs"
        return 0
    fi
    log "installing Python MCP tools via pipx …"
    pipx install mcp-atlassian 2>/dev/null || pipx upgrade mcp-atlassian 2>/dev/null || warn "mcp-atlassian install failed (non-fatal)"
    ok "mcp-atlassian ready: $(command -v mcp-atlassian 2>/dev/null || echo 'not found')"
}

install_rust_tools() {
    if ! command -v cargo >/dev/null 2>&1; then
        warn "cargo not found — skipping Rust tool installs (install rustup: https://rustup.rs)"
        return 0
    fi
    log "installing Rust MCP tools via cargo …"
    if command -v lean-ctx >/dev/null 2>&1; then
        ok "lean-ctx already installed: $(command -v lean-ctx)"
    else
        cargo install lean-ctx 2>/dev/null || warn "lean-ctx install failed (non-fatal)"
        ok "lean-ctx ready: $(command -v lean-ctx 2>/dev/null || echo 'not found')"
    fi
}

install_zellij() {
    log "ensuring zellij is installed …"
    bash "$DOTFILES_DIR/scripts/install/zellij.sh" || warn "zellij install reported errors (non-fatal)"
}

install_fonts() {
    local profile="$1"
    if [[ "$profile" == "server-headless" ]]; then
        log "skipping Nerd Font (headless profile)"
        return 0
    fi
    log "installing Nerd Font …"
    bash "$DOTFILES_DIR/scripts/install/nerd-fonts.sh" || warn "font install failed (non-fatal)"
}

apply_macos_defaults() {
    if is_macos && [[ -x "$DOTFILES_DIR/macos/defaults.sh" ]]; then
        log "applying macOS defaults …"
        bash "$DOTFILES_DIR/macos/defaults.sh" || warn "macOS defaults reported errors"
    fi
}

install_zed_config() {
    local profile="$1"
    if [[ "$profile" == "server-headless" ]]; then
        return 0
    fi
    if [[ -x "$DOTFILES_DIR/scripts/zed/install-zed-config.sh" ]]; then
        log "installing Zed config …"
        bash "$DOTFILES_DIR/scripts/zed/install-zed-config.sh" || warn "Zed config install had errors (non-fatal)"
    fi
}

install_vscodium_config() {
    local profile="$1"
    if [[ "$profile" == "server-headless" ]]; then
        return 0
    fi
    if [[ -x "$DOTFILES_DIR/scripts/vscodium/install-vscodium-config.sh" ]]; then
        log "installing VSCodium config …"
        bash "$DOTFILES_DIR/scripts/vscodium/install-vscodium-config.sh" --config || warn "VSCodium config install had errors (non-fatal)"
    fi
}

# -----------------------------------------------------------------------------
# Symlinks
# -----------------------------------------------------------------------------
install_symlinks() {
    log "creating symlinks …"
    bash "$DOTFILES_DIR/scripts/install/symlinks.sh"
}

# -----------------------------------------------------------------------------
# Claude Code skills (installed via npx skills add, linked into ~/.claude/skills/)
# -----------------------------------------------------------------------------
install_skills() {
    local list="$DOTFILES_DIR/.claude/skills/skills.list"
    local skills_dir="$HOME/.claude/skills"
    [[ -f "$list" ]] || return 0
    if ! command -v npx >/dev/null 2>&1; then
        warn "npx not found — skipping Claude Code skills install"
        return 0
    fi
    log "installing Claude Code skills from .claude/skills/skills.list …"
    while IFS= read -r source || [[ -n "$source" ]]; do
        [[ "$source" =~ ^#|^[[:space:]]*$ ]] && continue
        skill_name=$(basename "$source" | sed 's/-skill$//')
        if [[ -d "$HOME/.agents/skills/$skill_name" ]]; then
            ok "skill already installed: $skill_name"
        else
            log "installing skill: $source"
            npx --yes skills add "$source" --agent "Claude Code" --scope global --non-interactive 2>/dev/null \
                || warn "skill install failed: $source"
        fi
        # Ensure symlink uses absolute path (avoids dotfiles-symlink relative-path bug)
        local target="$HOME/.agents/skills/$skill_name"
        local link="$skills_dir/$skill_name"
        if [[ -d "$target" && (! -L "$link" || "$(readlink -f "$link" 2>/dev/null)" != "$target") ]]; then
            ln -sf "$target" "$link"
            ok "linked: $link -> $target"
        fi
    done < "$list"
}

# -----------------------------------------------------------------------------
# Claude Code MCP servers
# -----------------------------------------------------------------------------
install_mcp_servers() {
    local list="$DOTFILES_DIR/.claude/mcp-servers.list"
    [[ -f "$list" ]] || return 0
    if ! command -v claude >/dev/null 2>&1; then
        warn "claude CLI not found — skipping MCP server registration"
        return 0
    fi
    log "registering Claude Code MCP servers from .claude/mcp-servers.list …"
    while IFS='|' read -r name command args_rest || [[ -n "$name" ]]; do
        name="${name%%#*}"; name="${name// /}"
        [[ -z "$name" || "$name" == \#* ]] && continue
        command="${command// /}"
        command="${command/#\~/$HOME}"
        [[ -z "$command" ]] && { warn "MCP entry '$name' missing command — skipping"; continue; }
        IFS='|' read -ra arg_tokens <<< "$args_rest"
        local -a args=()
        for t in "${arg_tokens[@]}"; do
            t="${t# }"; t="${t% }"
            [[ -n "$t" ]] && args+=("$t")
        done
        claude mcp remove "$name" --scope user 2>/dev/null || true
        if claude mcp add --scope user "$name" -- "$command" "${args[@]}" 2>/dev/null; then
            ok "MCP registered: $name"
        else
            warn "MCP registration failed: $name"
        fi
    done < "$list"
}

# -----------------------------------------------------------------------------
# Doctor
# -----------------------------------------------------------------------------
run_doctor() {
    if [[ -x "$DOTFILES_DIR/scripts/doctor.sh" ]]; then
        bash "$DOTFILES_DIR/scripts/doctor.sh" "$@"
    else
        warn "scripts/doctor.sh not yet present"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    local mode="full"
    local fix_flag=""
    for arg in "$@"; do
        case "$arg" in
            --link-only)     mode="link";;
            --packages-only) mode="pkg";;
            --mcp-only)      mode="mcp";;
            --doctor)        mode="doctor";;
            --update|-u)     mode="update";;
            --fix)           fix_flag="--fix";;
            --profile=*)     ;;
            -h|--help)
                grep -E '^# ' "$0" | sed 's/^# //'
                exit 0
                ;;
            *) err "unknown arg: $arg"; exit 2;;
        esac
    done

    local profile
    profile="$(detect_profile "$@")"
    log "OS: $(uname -s)  profile: $profile  host: $(hostname -s 2>/dev/null || hostname)"

    case "$mode" in
        link)   install_symlinks ;;
        pkg)    install_packages "$profile" ;;
        mcp)    install_python_tools; install_mcp_servers ;;
        doctor) run_doctor $fix_flag ;;
        update)
            log "git pull --rebase --autostash …"
            (cd "$DOTFILES_DIR" && git pull --rebase --autostash) || warn "git pull failed (non-fatal)"
            install_packages "$profile" || warn "package install reported errors"
            install_symlinks
            install_python_tools
            install_rust_tools
            install_skills
            install_mcp_servers
            install_zellij
            install_fonts "$profile"
            install_zed_config "$profile"
            install_vscodium_config "$profile"
            run_doctor $fix_flag || true
            ok "update complete (profile: $profile)"
            ;;
        full)
            install_packages "$profile" || warn "package install reported errors"
            install_symlinks
            install_python_tools
            install_rust_tools
            install_skills
            install_mcp_servers
            install_zellij
            install_fonts "$profile"
            apply_macos_defaults
            install_zed_config "$profile"
            install_vscodium_config "$profile"
            run_doctor $fix_flag || true
            ok "bootstrap complete (profile: $profile)"
            ;;
    esac
}

main "$@"
