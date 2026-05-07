#!/usr/bin/env bash
# =============================================================================
# scripts/doctor.sh — diagnostic for dotfiles installation
# =============================================================================
# Reports OS, profile, symlinks, missing tools, syntax errors.
# Read-only — does not modify the system.
# =============================================================================

set -uo pipefail

FIX_MODE=false
for arg in "$@"; do
    case "$arg" in
        --fix) FIX_MODE=true ;;
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

if [[ -t 1 ]]; then
    G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; B='\033[0;34m'; N='\033[0m'
else
    G=''; Y=''; R=''; B=''; N=''
fi
ok()   { printf "${G}✓${N} %s\n" "$*"; }
warn() { printf "${Y}⚠${N} %s\n" "$*"; }
bad()  { printf "${R}✗${N} %s\n" "$*"; }
hdr()  { printf "\n${B}━━ %s ━━${N}\n" "$*"; }

is_macos()  { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux()  { [[ "$(uname -s)" == "Linux"  ]]; }
is_wsl()    { is_linux && { [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; }; }
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
    if is_wsl; then profile="wsl"
    elif is_macos; then profile="desktop-full"
    elif [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then profile="server-headless"
    else profile="desktop-full"
    fi
}
echo "Profile:   $profile"

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
check_link "$HOME/.zshrc"     "$DOTFILES_DIR/.zshrc"
check_link "$HOME/.zshenv"    "$DOTFILES_DIR/.zshenv"
check_link "$HOME/.gitconfig" "$DOTFILES_DIR/.gitconfig"

# ----- syntax -----
hdr "Shell syntax"
syn_err=0
for f in "$DOTFILES_DIR"/.zshrc "$DOTFILES_DIR"/.zshenv "$DOTFILES_DIR"/zsh/*.zsh "$DOTFILES_DIR"/zsh/lib/*.sh; do
    [[ -f "$f" ]] || continue
    case "$f" in
        *.zsh|*/.zshrc|*/.zshenv) zsh -n "$f" 2>&1 && ok "$(basename "$f")" || { bad "$(basename "$f")"; syn_err=$((syn_err+1)); } ;;
        *.sh)                     bash -n "$f" 2>&1 && ok "$(basename "$f")" || { bad "$(basename "$f")"; syn_err=$((syn_err+1)); } ;;
    esac
done

# ----- expected tools -----
hdr "Tools"
need_core=(zsh git curl)
need_modern=(starship zoxide fzf bat eza rg fd zellij)
need_workflow=(lazygit gh)

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
            fd)  command -v fdfind >/dev/null 2>&1 && ok "fd (fdfind)"  || warn "fd missing" ;;
            *)   warn "$cmd missing" ;;
        esac
    fi
done
echo
for cmd in "${need_workflow[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 && ok "$cmd" || warn "$cmd missing (workflow)"
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

# ----- claude -----
hdr "Claude Code"
claude_dir="$HOME/.claude"

check_claude_link() {
    local dst="$1" label="$2" fix="$3"
    if [[ -L "$dst" ]]; then
        ok "$label → $(readlink "$dst")"
    elif [[ -e "$dst" ]]; then
        warn "$label er ikke symlink — Fix: $fix"
    else
        bad "$label mangler — Fix: $fix"
    fi
}

check_claude_link "$claude_dir/settings.json" "~/.claude/settings.json" \
    "bash $DOTFILES_DIR/scripts/claude/install-claude-config.sh"
check_claude_link "$claude_dir/CLAUDE.md" "~/.claude/CLAUDE.md" \
    "bash $DOTFILES_DIR/scripts/claude/install-claude-config.sh"

for hook in rtk-rewrite.sh entroly-start.sh claude-session-check.sh; do
    hpath="$claude_dir/hooks/$hook"
    if [[ -L "$hpath" ]]; then
        if [[ -x "$hpath" ]]; then
            ok "hooks/$hook (symlink, eksekverbar)"
        else
            warn "hooks/$hook ikke eksekverbar — Fix: chmod +x $hpath"
            $FIX_MODE && chmod +x "$hpath" && ok "  → fixed"
        fi
    elif [[ -e "$hpath" ]]; then
        warn "hooks/$hook er ikke symlink"
    else
        bad "hooks/$hook mangler — Fix: bash $DOTFILES_DIR/scripts/claude/install-claude-config.sh"
    fi
done

# Token check (source secrets first)
# shellcheck disable=SC1090
[[ -f "$HOME/.local-secrets" ]] && set -a && source "$HOME/.local-secrets" 2>/dev/null && set +a
if [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
    ok "GITHUB_PERSONAL_ACCESS_TOKEN sat"
else
    warn "GITHUB_PERSONAL_ACCESS_TOKEN mangler — tilføj til ~/.local-secrets"
fi

# ----- MCP drift -----
# Reads ~/.claude.json directly instead of `claude mcp list` to avoid
# spawning every stdio server for health checks (engram MCPs trigger SSH
# host-key prompts when superbro is not yet trusted).
hdr "MCP drift (mcp-servers.list vs ~/.claude.json)"
mcp_list_file="$DOTFILES_DIR/.claude/mcp-servers.list"
claude_json="$HOME/.claude.json"
if [[ ! -f "$claude_json" ]]; then
    warn "$claude_json missing — skipping MCP drift check"
elif ! command -v jq >/dev/null 2>&1; then
    warn "jq not found — skipping MCP drift check (install jq to enable)"
elif [[ ! -f "$mcp_list_file" ]]; then
    warn "$mcp_list_file missing — skipping MCP drift check"
else
    declared="$(awk -F'|' '
        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
        { gsub(/[[:space:]]/, "", $1); if ($1 != "") print $1 }
    ' "$mcp_list_file" | sort -u)"

    registered="$(jq -r '.mcpServers // {} | keys[]' "$claude_json" 2>/dev/null | sort -u)"

    missing="$(comm -23 <(echo "$declared") <(echo "$registered"))"
    extra="$(comm -13 <(echo "$declared") <(echo "$registered"))"

    if [[ -z "$missing" && -z "$extra" ]]; then
        ok "MCP servers in sync ($(echo "$declared" | wc -l | tr -d ' ') entries)"
    fi
    if [[ -n "$missing" ]]; then
        while IFS= read -r n; do
            [[ -n "$n" ]] && bad "MCP missing locally: $n — Fix: ./bootstrap.sh --mcp-only"
        done <<< "$missing"
    fi
    if [[ -n "$extra" ]]; then
        while IFS= read -r n; do
            [[ -n "$n" ]] && warn "MCP registered but not in list: $n — Fix: claude mcp remove $n --scope user (or add to mcp-servers.list)"
        done <<< "$extra"
    fi
fi

# ----- engram SSH reachability -----
# Engram MCPs spawn `ssh superbro …` at runtime. If superbro's host key is
# not in known_hosts under that alias, SSH blocks on a yes/no prompt and the
# MCP server never starts. Probe non-interactively so doctor never blocks.
hdr "Engram SSH (superbro)"
if ! command -v ssh >/dev/null 2>&1; then
    warn "ssh not installed — engram MCPs will not work"
else
    ssh_probe="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
                     -o ConnectTimeout=3 -o ServerAliveInterval=2 \
                     superbro 'echo ok' 2>&1)"
    if [[ "$ssh_probe" == "ok" ]]; then
        ok "ssh superbro reachable"
    elif grep -q "host key.* not.* known\|authenticity\|Host key verification failed" <<< "$ssh_probe"; then
        warn "ssh superbro host key not trusted under alias 'superbro' — Fix: ssh superbro (accept once) or add HostKeyAlias to ~/.ssh/config"
    elif grep -q "Permission denied" <<< "$ssh_probe"; then
        warn "ssh superbro auth failed — check ~/.ssh/id_* and authorized_keys on superbro"
    elif grep -q "Could not resolve\|Name or service not known\|No route to host\|[Cc]onnection.*timed out\|Connection refused" <<< "$ssh_probe"; then
        warn "ssh superbro unreachable (Tailscale up? host alias defined?)"
    else
        warn "ssh superbro probe failed: $(echo "$ssh_probe" | head -1)"
    fi
fi

# ----- summary -----
hdr "Summary"
if (( syn_err > 0 )); then
    bad "$syn_err shell syntax error(s)"
    exit 1
fi
ok "Doctor completed."
