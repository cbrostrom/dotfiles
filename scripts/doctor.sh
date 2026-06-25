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

for hook in entroly-start.sh claude-session-check.sh effort-classifier.sh; do
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

# ----- shared rules (cross-tool: Claude + Cursor) -----
hdr "Shared rules (Claude + Cursor)"
shared_rules_dir="$DOTFILES_DIR/.shared-rules"
canonical_engram="$shared_rules_dir/engram-graphiti.md"
cursor_marker="$shared_rules_dir/.cursor-synced"

if [[ ! -f "$canonical_engram" ]]; then
    bad "canonical $canonical_engram missing — Fix: re-pull dotfiles or run shared-rules setup"
else
    ok "canonical engram-graphiti.md present"
fi

claude_engram_link="$HOME/.claude/engram-graphiti.md"
if [[ -L "$claude_engram_link" ]]; then
    if [[ "$(readlink -f "$claude_engram_link" 2>/dev/null || realpath "$claude_engram_link" 2>/dev/null)" == "$canonical_engram" ]]; then
        ok "~/.claude/engram-graphiti.md → canonical (Claude @-includes via CLAUDE.md)"
    else
        warn "~/.claude/engram-graphiti.md points elsewhere — Fix: ln -sfn $canonical_engram $claude_engram_link"
    fi
elif [[ -e "$claude_engram_link" ]]; then
    warn "~/.claude/engram-graphiti.md is not a symlink — Fix: rm + ln -sfn"
else
    bad "~/.claude/engram-graphiti.md missing — Fix: ln -sfn $canonical_engram $claude_engram_link"
fi

# Drift: warn if canonical is newer than the cursor-synced marker.
# User pastes content into Cursor cloud User Rules manually, then `touch .cursor-synced`.
if [[ -f "$canonical_engram" && -f "$cursor_marker" ]]; then
    if [[ "$canonical_engram" -nt "$cursor_marker" ]]; then
        warn "engram-graphiti.md edited after last Cursor sync — re-paste into Cursor cloud User Rules, then: touch $cursor_marker"
    else
        ok "Cursor User Rules in sync with canonical (per marker)"
    fi
elif [[ -f "$canonical_engram" && ! -f "$cursor_marker" ]]; then
    warn "no .cursor-synced marker yet — paste canonical into Cursor cloud User Rules, then: touch $cursor_marker"
fi

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


# ----- engram local + sync diagnostic -----
hdr "engram local + git sync"
if is_wsl; then
    WIN_HOME="/mnt/c/Users/${USER}"
    ENGRAM_BIN="${WIN_HOME}/go/bin/engram.exe"
    ENGRAM_ROOT="${WIN_HOME}/.engram"
    if [[ -x "$ENGRAM_BIN" ]]; then
        ok "engram (WSL→Windows): $ENGRAM_BIN ($("$ENGRAM_BIN" version 2>/dev/null | head -1 || echo '?'))"
    else
        warn "engram Windows binary missing: $ENGRAM_BIN — Fix: (PowerShell) go install github.com/Gentleman-Programming/engram/cmd/engram@latest"
    fi
elif command -v engram >/dev/null 2>&1; then
    ok "engram on PATH: $(command -v engram) ($(engram version 2>/dev/null | head -1))"
else
    case "$(uname -s)" in
        Darwin) warn "engram not on PATH — Fix: go install github.com/Gentleman-Programming/engram/cmd/engram@latest" ;;
        Linux)  warn "engram not on PATH — Fix: go install github.com/Gentleman-Programming/engram/cmd/engram@latest" ;;
        *)      warn "engram not on PATH — see https://github.com/Gentleman-Programming/engram" ;;
    esac
fi
for vault in personal work; do
    if is_wsl; then
        vault_dir="${ENGRAM_ROOT:-/mnt/c/Users/${USER}/.engram}/$vault"
    else
        vault_dir="$HOME/.engram/$vault"
    fi
    if [[ -d "$vault_dir" ]]; then
        ok "vault $vault: $vault_dir"
    else
        warn "vault $vault missing: $vault_dir"
    fi
done
if is_wsl; then
    sync_repo="/mnt/c/Users/${USER}/.engram"
else
    sync_repo="$HOME/engram-sync"
fi
if [[ -d "$sync_repo/.git" ]]; then
    remote="$(git -C "$sync_repo" remote get-url origin 2>/dev/null || echo none)"
    if [[ "$remote" == "git@github.com:cbrostrom/engram.git" ]]; then
        ok "$sync_repo origin → cbrostrom/engram"
    else
        warn "$sync_repo origin: $remote (expected git@github.com:cbrostrom/engram.git)"
    fi
    if git -C "$sync_repo" rev-parse '@{u}' >/dev/null 2>&1; then
        pending="$(git -C "$sync_repo" log '@{u}..HEAD' --oneline 2>/dev/null | wc -l | tr -d ' ')"
        if (( pending > 0 )); then
            warn "$pending unpushed commit(s) in $sync_repo — Fix: cd $sync_repo && git push"
        else
            ok "$sync_repo in sync with origin"
        fi
    else
        local_commits="$(git -C "$sync_repo" log --oneline 2>/dev/null | wc -l | tr -d ' ')"
        warn "$sync_repo has no upstream tracking ($local_commits local commit(s) never pushed) — Fix: cd $sync_repo && git push -u origin main"
    fi
else
    warn "$sync_repo not a git repo — Fix: bash $DOTFILES_DIR/scripts/install/engram.sh"
fi
case "$(uname -s)" in
    Darwin)
        plist="$HOME/Library/LaunchAgents/dk.brostrom.engram-sync.plist"
        if launchctl list dk.brostrom.engram-sync >/dev/null 2>&1; then
            last_exit="$(launchctl list dk.brostrom.engram-sync 2>/dev/null | awk '/LastExitStatus/{print $3}' | tr -d ';"')"
            if [[ "$last_exit" == "0" || -z "$last_exit" ]]; then
                ok "launchd dk.brostrom.engram-sync loaded (last exit: ${last_exit:-not yet run})"
            else
                warn "launchd dk.brostrom.engram-sync last exit=$last_exit — Fix: tail ~/Library/Logs/engram-sync.log"
            fi
        elif [[ -f "$plist" ]]; then
            warn "launchd plist exists but not loaded — Fix: launchctl load $plist"
        else
            warn "launchd plist missing — Fix: bash $DOTFILES_DIR/scripts/install/engram.sh"
        fi
        log_file="$HOME/Library/Logs/engram-sync.log"
        ;;
    Linux)
        if systemctl --user is-enabled engram-sync.timer >/dev/null 2>&1; then
            timer_state="$(systemctl --user is-active engram-sync.timer 2>/dev/null)"
            path_state="$(systemctl --user is-active engram-sync.path 2>/dev/null)"
            if [[ "$timer_state" == "active" && "$path_state" == "active" ]]; then
                ok "systemd-user engram-sync.{timer,path} active"
            else
                warn "systemd-user units not fully active (timer=$timer_state, path=$path_state) — Fix: systemctl --user start engram-sync.timer engram-sync.path"
            fi
            last_exit="$(systemctl --user show engram-sync.service -p ExecMainStatus --value 2>/dev/null)"
            [[ -n "$last_exit" && "$last_exit" != "0" ]] && warn "engram-sync.service last exit=$last_exit — Fix: journalctl --user -u engram-sync.service -n 30"
            if ! loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
                warn "linger NOT enabled — timers stop on logout. Fix: sudo loginctl enable-linger $USER"
            fi
        elif command -v systemctl >/dev/null 2>&1; then
            warn "engram-sync systemd-user units not enabled — Fix: bash $DOTFILES_DIR/scripts/install/engram.sh"
        else
            warn "systemctl not found — WSL? Enable systemd in /etc/wsl.conf, then wsl --shutdown"
        fi
        log_file="${XDG_STATE_HOME:-$HOME/.local/state}/engram-sync.log"
        ;;
esac
if [[ -n "${log_file:-}" && -f "$log_file" ]]; then
    last_line="$(tail -1 "$log_file" 2>/dev/null)"
    last_mtime="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$log_file" 2>/dev/null \
                || stat -c '%y' "$log_file" 2>/dev/null | cut -d'.' -f1)"
    echo "  last sync log: $last_mtime"
    [[ -n "$last_line" ]] && echo "    $last_line"
fi

# ----- graphiti remote health -----
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

# ----- MCP staleness diagnostic -----
# Reports last-modified time on MCP config files vs running engram-related
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
    | grep -E 'engram mcp|graphiti|mcp-mermaid|tailwindcss-mcp|shopify.*dev-mcp|apple-mcp|@modelcontextprotocol/server-github' \
    | grep -v 'grep -E' \
    | wc -l | tr -d ' ')"
echo "  Running MCP-related processes (this host): $running_mcp"
if (( running_mcp == 0 )); then
    warn "No MCP processes running. Cursor/Claude load mcp.json at session start — restart the agent after editing config."
else
    if (( running_mcp > 30 )); then
        warn "Unusually high MCP process count ($running_mcp). Possible leaked processes from previous agent sessions — Fix: pkill -f 'engram mcp|graphiti|mcp-mermaid|tailwindcss-mcp|shopify.*dev-mcp|apple-mcp|server-github' (then relaunch agent)"
    else
        echo "  If a recently-edited server isn't responding, restart the agent fully (Cmd+Q for IDE, exit/reopen for CLI)."
    fi
fi

# ----- summary -----
hdr "Summary"
if (( syn_err > 0 )); then
    bad "$syn_err shell syntax error(s)"
fi
if ! $QUIET_MODE; then
    ok "Doctor completed."
fi
exit $(( _DOCTOR_ISSUES > 125 ? 125 : _DOCTOR_ISSUES ))
