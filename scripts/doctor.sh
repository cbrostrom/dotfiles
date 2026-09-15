#!/usr/bin/env bash
# =============================================================================
# scripts/doctor.sh — diagnostic for dotfiles installation
# =============================================================================
# Reports OS, profile, symlinks, missing tools, syntax errors.
# Read-only — does not modify the system.
# =============================================================================

set -uo pipefail

FIX_MODE=false
QUIET_MODE=false
for arg in "$@"; do
    case "$arg" in
        --fix) FIX_MODE=true ;;
        --quiet) QUIET_MODE=true ;;
    esac
done

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure Homebrew is in PATH for accurate tool detection
for _brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [[ -x "$_brew_bin" ]]; then
        eval "$("$_brew_bin" shellenv)"
        break
    fi
done
unset _brew_bin

if [[ -t 1 ]] && ! $QUIET_MODE; then
    G='\033[0;32m'
    Y='\033[1;33m'
    R='\033[0;31m'
    B='\033[0;34m'
    N='\033[0m'
else
    G=''
    Y=''
    R=''
    B=''
    N=''
fi
_DOCTOR_ISSUES=0
ok() { printf "${G}✓${N} %s\n" "$*"; }
hdr() { printf "\n${B}━━ %s ━━${N}\n" "$*"; }
skip() { printf "${N}⊘ %s\n" "$*"; }
warn() {
    ((_DOCTOR_ISSUES++)) || true
    printf "${Y}⚠${N} %s\n" "$*"
}
bad() {
    ((_DOCTOR_ISSUES++)) || true
    printf "${R}✗${N} %s\n" "$*"
}

# In quiet mode: suppress all output, only exit code carries issue count.
if $QUIET_MODE; then
    ok() { :; }
    hdr() { :; }
    skip() { :; }
    warn() { ((_DOCTOR_ISSUES++)) || true; }
    bad() { ((_DOCTOR_ISSUES++)) || true; }
fi

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux() { [[ "$(uname -s)" == "Linux" ]]; }
is_wsl() { is_linux && { [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; }; }
is_debian() { is_linux && [[ -f /etc/debian_version ]]; }

# ----- environment -----
hdr "Environment"
echo "OS:        $(uname -s) $(uname -r)"
echo "Host:      $(hostname -s 2>/dev/null || hostname)"
echo "Shell:     ${SHELL:-?}"
echo "DOTFILES:  $DOTFILES_DIR"

profile=""
[[ -f "$HOME/.local-config" ]] && profile="$(grep -E '^PROFILE=' "$HOME/.local-config" 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'")"
[[ -z "$profile" ]] && {
    if is_wsl; then
        profile="wsl"
    elif is_macos; then
        profile="desktop-full"
    elif [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
        profile="server-headless"
    else
        profile="desktop-full"
    fi
}
echo "Profile:   $profile"

if is_wsl; then
    # WSL Performance Guard: check if project dirs are in /mnt/c/
    # We check for any active projects (directories with .git) in /mnt/
    bad_paths="$(find /mnt -maxdepth 3 -name .git -type d 2>/dev/null)"
    if [[ -n "$bad_paths" ]]; then
        warn "WSL PERFORMANCE RISK: Found .git repos in /mnt/ (Windows filesystem). Move projects to the Linux root (~/) for 10x faster AI agent performance."
    else
        ok "Project paths optimal (native Linux root)"
    fi
fi

# Headless servers skip desktop-only Cursor sections
is_headless=false
[[ "$profile" == "server-headless" ]] && is_headless=true

# ----- symlinks -----
hdr "Symlinks"
check_link() {
    local target="$1" expect="$2"
    if [[ -L "$target" ]]; then
        local actual resolved
        actual="$(readlink "$target")"
        resolved="$(readlink -f "$target" 2>/dev/null || realpath "$target" 2>/dev/null || echo "")"
        if [[ "$resolved" == "$expect" ]]; then
            ok "$target → $actual"
        else
            warn "$target → $actual (expected $expect)"
        fi
    elif [[ -e "$target" ]]; then
        warn "$target exists but is not a symlink"
    else
        bad "$target missing"
    fi
}
check_link "$HOME/.zshrc" "$DOTFILES_DIR/.zshrc"
check_link "$HOME/.zshenv" "$DOTFILES_DIR/.zshenv"
check_link "$HOME/.gitconfig" "$DOTFILES_DIR/.gitconfig"

# ----- syntax -----
hdr "Shell syntax"
syn_err=0
for f in "$DOTFILES_DIR"/.zshrc "$DOTFILES_DIR"/.zshenv "$DOTFILES_DIR"/zsh/*.zsh "$DOTFILES_DIR"/zsh/lib/*.sh; do
    [[ -f "$f" ]] || continue
    case "$f" in
        *.zsh | */.zshrc | */.zshenv) zsh -n "$f" 2>&1 && ok "$(basename "$f")" || {
            bad "$(basename "$f")"
            syn_err=$((syn_err + 1))
        } ;;
        *.sh) bash -n "$f" 2>&1 && ok "$(basename "$f")" || {
            bad "$(basename "$f")"
            syn_err=$((syn_err + 1))
        } ;;
    esac
done

# ----- expected tools -----
hdr "Tools"
need_core=(zsh git curl)
need_modern=(starship zoxide fzf bat eza rg fd)
need_workflow=(gh)
optional_workflow=(lazygit)

for cmd in "${need_core[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 && ok "$cmd" || bad "$cmd missing (REQUIRED)"
done
echo
for cmd in "${need_modern[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd"
    else
        # Debian renames bat→batcat, fd→fdfind
        case "$cmd" in
            bat) command -v batcat >/dev/null 2>&1 && ok "bat (batcat)" || warn "bat missing" ;;
            fd) command -v fdfind >/dev/null 2>&1 && ok "fd (fdfind)" || warn "fd missing" ;;
            *) warn "$cmd missing" ;;
        esac
    fi
done
echo
for cmd in "${need_workflow[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 && ok "$cmd" || warn "$cmd missing (workflow)"
done
for cmd in "${optional_workflow[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 && ok "$cmd" || skip "$cmd not installed (optional)"
done

# ----- secrets -----
hdr "Secrets"
if [[ -e "$HOME/.local-secrets" ]]; then
    secrets_target="$(readlink -f "$HOME/.local-secrets" 2>/dev/null || echo "$HOME/.local-secrets")"
    perms="$(stat -c '%a' "$secrets_target" 2>/dev/null || stat -f '%Lp' "$secrets_target" 2>/dev/null)"
    if [[ "$perms" == "600" ]]; then
        ok "~/.local-secrets exists (chmod 600)"
    else
        warn "~/.local-secrets has perms $perms — should be 600"
        echo "    Fix: chmod 600 $secrets_target"
        if $FIX_MODE; then
            chmod 600 "$secrets_target" && ok "  → fixed (chmod 600)"
        fi
    fi
else
    warn "~/.local-secrets not present (copy from .local-secrets.example)"
fi

# ----- opencode -----
hdr "OpenCode"
if command -v opencode >/dev/null 2>&1; then
    ok "opencode on PATH: $(command -v opencode)"
else
    bad "opencode not on PATH — Fix: curl -fsSL https://opencode.ai/install | bash"
fi

oc_cfg="$HOME/.config/opencode/opencode.json"
if [[ -L "$oc_cfg" ]]; then
    ok "~/.config/opencode/opencode.json → $(readlink "$oc_cfg")"
elif [[ -e "$oc_cfg" ]]; then
    warn "~/.config/opencode/opencode.json exists but is not a symlink"
else
    bad "~/.config/opencode/opencode.json missing — Fix: bootstrap.sh --only=opencode"
fi

oc_agents="$HOME/.config/opencode/AGENTS.md"
if [[ -L "$oc_agents" ]]; then
    ok "~/.config/opencode/AGENTS.md → $(readlink "$oc_agents")"
elif [[ -e "$oc_agents" ]]; then
    warn "~/.config/opencode/AGENTS.md exists but is not a symlink"
else
    bad "~/.config/opencode/AGENTS.md missing — Fix: bootstrap.sh --only=opencode"
fi

oc_skills="$HOME/.config/opencode/skills"
if [[ -L "$oc_skills" ]]; then
    ok "~/.config/opencode/skills → $(readlink "$oc_skills")"
elif [[ -e "$oc_skills" ]]; then
    warn "~/.config/opencode/skills exists but is not a symlink"
else
    warn "~/.config/opencode/skills missing — opencode won't discover shared skills"
fi

# ----- pi extensions (manifest) -----
pi_ext_list="$DOTFILES_DIR/scripts/install/pi-extensions.txt"
if [[ -f "$pi_ext_list" ]]; then
    while IFS= read -r _spec; do
        _spec="${_spec%%#*}"
        _spec="$(echo "$_spec" | tr -d '[:space:]')"
        [[ -z "$_spec" ]] && continue
        case "$_spec" in
            git:*)
                _path="${_spec#git:}"
                if [[ -d "$HOME/.pi/agent/git/$_path/.git" ]]; then
                    ok "pi ext: git:$_path"
                else
                    warn "pi ext missing: $_spec — Fix: ~/dotfiles/scripts/install/pi-extensions.sh"
                fi
                ;;
            npm:*)
                _name="${_spec#npm:}"
                if [[ -f "$HOME/.pi/agent/npm/node_modules/$_name/package.json" ]]; then
                    ok "pi ext: npm:$_name"
                else
                    warn "pi ext missing: $_spec — Fix: ~/dotfiles/scripts/install/pi-extensions.sh"
                fi
                ;;
        esac
    done < "$pi_ext_list"
else
    warn "pi-extensions.txt manifest missing (expected $pi_ext_list)"
fi

# ----- shared rules (Cursor) -----
# Skipped on headless servers
if [[ "$is_headless" == "false" ]]; then
    hdr "Shared rules (Cursor)"
    shared_rules_dir="$DOTFILES_DIR/.shared-rules"
    cursor_marker="$shared_rules_dir/.cursor-synced"

    if [[ -f "$cursor_marker" ]]; then
        ok "Cursor User Rules in sync with canonical (per marker)"
    else
        warn "no .cursor-synced marker yet — paste canonical into Cursor cloud User Rules, then: touch $cursor_marker"
    fi
fi # is_headless

# ----- rbw (Bitwarden CLI) module -----
hdr "rbw (Bitwarden CLI module)"
rbw_env_script="$DOTFILES_DIR/modules/rbw/env-secrets.zsh"
rbw_config="$HOME/.config/rbw/config.json"

if command -v rbw >/dev/null 2>&1; then
    rbw_ver="$(rbw --version 2>/dev/null | head -1 || echo unknown)"
    ok "rbw installed: $rbw_ver"
    if rbw status 2>/dev/null | grep -q -i "locked"; then
        warn "rbw vault locked — Fix: rbw unlock (then restart shells / Cursor / Pi to refresh env)"
    elif rbw status 2>/dev/null | grep -q -i "unlocked"; then
        ok "rbw vault unlocked"
    fi
else
    skip "rbw not installed (module is opt-in via modules.conf)"
fi

if [[ -f "$rbw_config" ]]; then
    rbw_perms="$(stat -c '%a' "$rbw_config" 2>/dev/null || stat -f '%Lp' "$rbw_config" 2>/dev/null)"
    if [[ "$rbw_perms" == "600" ]]; then
        ok "$rbw_config (chmod 600)"
    else
        warn "$rbw_config has perms $rbw_perms — should be 600"
        $FIX_MODE && chmod 600 "$rbw_config" && ok "  → fixed (chmod 600)"
    fi
fi

if [[ -f "$rbw_env_script" ]]; then
    if grep -q "modules/rbw/env-secrets.zsh" "$DOTFILES_DIR/.zshenv" 2>/dev/null; then
        ok ".zshenv sources env-secrets.zsh"
    else
        bad ".zshenv does NOT source modules/rbw/env-secrets.zsh — Fix: see modules/rbw/install.sh"
    fi
fi

# ----- Cursor MCP config hygiene -----
# Skipped on headless servers
if [[ "$is_headless" == "false" ]]; then
    hdr "Cursor MCP"
    cursor_json="$HOME/.cursor/mcp.json"
    if [[ ! -f "$cursor_json" ]]; then
        skip "$cursor_json missing — Cursor MCP not configured on this host"
    elif ! command -v jq >/dev/null 2>&1; then
        warn "jq not found — skipping Cursor MCP check"
    else
        cursor_n="$(jq -r '.mcpServers // {} | keys | length' "$cursor_json" 2>/dev/null || echo 0)"
        ok "Cursor MCP servers: $cursor_n"
        if jq -e '.mcpServers | to_entries[] | select(.value.env? | (objects | values[]?) | tostring | test("^(ghp_|gho_|ghs_|sk-|xoxb-|atlas)"; "i"))' "$cursor_json" >/dev/null 2>&1; then
            bad "Cursor mcp.json contains likely inline secret in env — Fix: move to env var sourced from .zshenv (rbw)"
        else
            ok "Cursor mcp.json has no obvious inline tokens"
        fi
    fi
fi # is_headless

# ----- summary -----
hdr "Summary"
if ((syn_err > 0)); then
    bad "$syn_err shell syntax error(s)"
fi
if ! $QUIET_MODE; then
    ok "Doctor completed."
fi
exit $((_DOCTOR_ISSUES > 125 ? 125 : _DOCTOR_ISSUES))
