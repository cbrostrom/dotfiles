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
        --fix)   FIX_MODE=true ;;
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
    G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; B='\033[0;34m'; N='\033[0m'
else
    G=''; Y=''; R=''; B=''; N=''
fi
_DOCTOR_ISSUES=0
ok()   { printf "${G}✓${N} %s\n" "$*"; }
hdr()  { printf "\n${B}━━ %s ━━${N}\n" "$*"; }
skip() { printf "${N}⊘ %s\n" "$*"; }
warn() { (( _DOCTOR_ISSUES++ )) || true; printf "${Y}⚠${N} %s\n" "$*"; }
bad()  { (( _DOCTOR_ISSUES++ )) || true; printf "${R}✗${N} %s\n" "$*"; }

# In quiet mode: suppress all output, only exit code carries issue count.
if $QUIET_MODE; then
    ok()   { : ; }
    hdr()  { : ; }
    skip() { : ; }
    warn() { (( _DOCTOR_ISSUES++ )) || true; }
    bad()  { (( _DOCTOR_ISSUES++ )) || true; }
fi

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

# Headless servers skip Claude/Cursor/engram/graphiti/MCP sections
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
need_modern=(starship zoxide fzf bat eza rg fd)
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

# ----- claude -----
# Skipped on headless servers (opencode is the agent)
if [[ "$is_headless" == "false" ]]; then
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

for hook in effort-classifier.sh; do
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
fi # is_headless

# ----- MCP drift -----
# Skipped on headless servers
if [[ "$is_headless" == "false" ]]; then
# Reads ~/.claude.json directly instead of `claude mcp list` to avoid
# spawning every stdio server for health checks.
# Uses lists_merge for proper platform/profile/host overlay resolution.
hdr "MCP drift (mcp-servers.list vs ~/.claude.json)"
mcp_base="$DOTFILES_DIR/.claude/mcp-servers.list"
claude_json="$HOME/.claude.json"
if [[ ! -f "$claude_json" ]]; then
    warn "$claude_json missing — skipping MCP drift check"
elif ! command -v jq >/dev/null 2>&1; then
    warn "jq not found — skipping MCP drift check (install jq to enable)"
elif [[ ! -f "$mcp_base" ]]; then
    warn "$mcp_base missing — skipping MCP drift check"
else
    . "$DOTFILES_DIR/modules/_lib/platform.sh"
    . "$DOTFILES_DIR/modules/_lib/lists.sh"

    declared="$(lists_merge "$mcp_base" | awk -F'|' '
        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
        { gsub(/[[:space:]]/, "", $1); if ($1 != "") print $1 }
    ' | sort -u)"

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
fi # is_headless

# ----- shared rules (cross-tool: Claude + Cursor) -----
# Skipped on headless servers
if [[ "$is_headless" == "false" ]]; then
hdr "Shared rules (Claude + Cursor)"
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
        warn "rbw vault locked — Fix: rbw unlock (then restart shells / Cursor / Claude to refresh env)"
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

# ----- Cursor MCP drift (~/.cursor/mcp.json vs ~/.claude.json) -----
# Skipped on headless servers
if [[ "$is_headless" == "false" ]]; then
# Goal: keep Cursor and Claude in lock-step on MCP servers. User explicitly
# wants alignment; this surfaces drift fast.
hdr "Cursor MCP parity (vs Claude)"
cursor_json="$HOME/.cursor/mcp.json"
if [[ ! -f "$cursor_json" ]]; then
    skip "$cursor_json missing — Cursor MCP not configured on this host"
elif ! command -v jq >/dev/null 2>&1; then
    warn "jq not found — skipping Cursor MCP parity check"
elif [[ ! -f "$claude_json" ]]; then
    skip "$claude_json missing — cannot compare"
else
    cursor_keys="$(jq -r '.mcpServers // {} | keys[]' "$cursor_json" 2>/dev/null | sort -u)"
    claude_keys="$(jq -r '.mcpServers // {} | keys[]' "$claude_json" 2>/dev/null | sort -u)"

    only_claude="$(comm -23 <(echo "$claude_keys") <(echo "$cursor_keys"))"
    only_cursor="$(comm -13 <(echo "$claude_keys") <(echo "$cursor_keys"))"

    if [[ -z "$only_claude" && -z "$only_cursor" ]]; then
        ok "Cursor MCP matches Claude ($(echo "$cursor_keys" | wc -l | tr -d ' ') servers)"
    fi
    if [[ -n "$only_claude" ]]; then
        while IFS= read -r n; do
            [[ -n "$n" ]] && warn "MCP in Claude but not Cursor: $n — Fix: add to ~/.cursor/mcp.json"
        done <<< "$only_claude"
    fi
    if [[ -n "$only_cursor" ]]; then
        while IFS= read -r n; do
            [[ -n "$n" ]] && warn "MCP in Cursor but not Claude: $n — Fix: add to ~/.claude.json"
        done <<< "$only_cursor"
    fi

    # Check Cursor has no inline tokens in env (security)
    if jq -e '.mcpServers | to_entries[] | select(.value.env? | (objects | values[]?) | tostring | test("^(ghp_|gho_|ghs_|sk-|xoxb-|atlas)"; "i"))' "$cursor_json" >/dev/null 2>&1; then
        bad "Cursor mcp.json contains likely inline secret in env — Fix: move to env var sourced from .zshenv (rbw)"
    else
        ok "Cursor mcp.json has no obvious inline tokens"
    fi
fi
fi # is_headless


# ----- engram local + sync diagnostic -----
# REMOVED in favor of local vaults (Higgins)
# This section is intentionally left empty or can be removed.
:

# ----- graphiti remote health -----
# Skipped on headless servers
if [[ "$is_headless" == "false" ]]; then
hdr "graphiti remote (HTTP MCP over Tailscale)"
graphiti_url="${GRAPHITI_HEALTH_URL:-http://100.100.1.50:8000/health}"
if command -v curl >/dev/null 2>&1; then
    if resp="$(curl -fsS --max-time 3 "$graphiti_url" 2>/dev/null)"; then
        if echo "$resp" | grep -q '"status":"healthy"'; then
            ok "graphiti reachable: $graphiti_url ($resp)"
        else
            warn "graphiti reachable but unexpected response: $resp"
        fi
    else
        warn "graphiti unreachable at $graphiti_url — Fix: ssh superbro 'docker compose -f /path/to/graphiti/docker-compose.yml restart' (or check tailscale)"
    fi
else
    warn "curl not installed — cannot probe graphiti"
fi
fi # is_headless

# ----- MCP staleness diagnostic -----
# Skipped on headless servers
if [[ "$is_headless" == "false" ]]; then
# Reports last-modified time on MCP config files vs running non-engram-related
# processes. Useful when "MCP updates aren't coming through" — usually it's
# because Cursor / Claude need a session restart.
hdr "MCP config freshness"
for cfg in "$HOME/.cursor/mcp.json" "$HOME/.claude.json"; do
    if [[ -f "$cfg" ]]; then
        mtime="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$cfg" 2>/dev/null \
              || stat -c '%y' "$cfg" 2>/dev/null | cut -d'.' -f1)"
        echo "  $cfg  (modified: $mtime)"
    fi
done
# Portable across macOS/Linux: ps + grep. Exclude grep itself + own process.
running_mcp="$(ps -A -o pid,command 2>/dev/null \
    | grep -E 'graphiti|mcp-mermaid|tailwindcss-mcp|shopify.*dev-mcp|apple-mcp|@modelcontextprotocol/server-github' \
    | grep -v 'grep -E' \
    | wc -l | tr -d ' ')"
echo "  Running MCP-related processes (this host): $running_mcp"
if (( running_mcp == 0 )); then
    warn "No MCP processes running. Cursor/Claude load mcp.json at session start — restart the agent after editing config."
else
    if (( running_mcp > 30 )); then
        warn "Unusually high MCP process count ($running_mcp). Possible leaked processes from previous agent sessions — Fix: pkill -f 'graphiti|mcp-mermaid|tailwindcss-mcp|shopify.*dev-mcp|apple-mcp|server-github' (then relaunch agent)"
    else
        echo "  If a recently-edited server isn't responding, restart the agent fully (Cmd+Q for IDE, exit/reopen for CLI)."
    fi
fi
fi # is_headless

# ----- summary -----
hdr "Summary"
if (( syn_err > 0 )); then
    bad "$syn_err shell syntax error(s)"
fi
if ! $QUIET_MODE; then
    ok "Doctor completed."
fi
exit $(( _DOCTOR_ISSUES > 125 ? 125 : _DOCTOR_ISSUES ))
