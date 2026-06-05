# =============================================================================
# env-secrets.zsh — pull tokens from Bitwarden into env via rbw
# =============================================================================
# Sourced from .zshenv on every shell invocation (interactive, scripts, MCP
# child processes spawned by GUI Cursor/Claude). Keep it fast and silent.
#
# Each token is fetched with a 1-second timeout — if rbw-agent is locked,
# the variable ends up empty and the dependent service fails loudly. To
# refresh: `rbw unlock` then start a new shell / restart Cursor or Claude.
#
# Bitwarden item names are case-sensitive. Match exactly what you see in
# the Bitwarden vault item title.
# =============================================================================

# Bail early if rbw is not installed — keeps non-rbw machines silent.
command -v rbw >/dev/null 2>&1 || return 0

# Fast path 1: already in env (subshell/script inheriting from parent shell)
[[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN+set}" ]] && return 0

# Fast path 2: source from cache file written on last unlock (survives new terminal windows)
_RBW_ENV_CACHE="${XDG_RUNTIME_DIR:-/tmp}/rbw-env-$UID.zsh"
if [[ -f "$_RBW_ENV_CACHE" ]] && [[ $(find "$_RBW_ENV_CACHE" -mmin -480 2>/dev/null) ]]; then
    source "$_RBW_ENV_CACHE"
    unset _RBW_ENV_CACHE
    return 0
fi
unset _RBW_ENV_CACHE

# Pick a timeout impl. macOS has no `timeout` by default; coreutils brings
# `gtimeout`. Falls back to bare rbw (no hang protection) if neither exists.
if command -v timeout >/dev/null 2>&1; then
    _dotfiles_bw_timeout="timeout 1"
elif command -v gtimeout >/dev/null 2>&1; then
    _dotfiles_bw_timeout="gtimeout 1"
else
    _dotfiles_bw_timeout=""
fi

# Guard: only proceed if vault is actually unlocked.
# `rbw unlocked` exits 0 if unlocked, non-0 otherwise — no pinentry triggered.
# rbw list / rbw get with a locked vault spawns pinentry-curses via rbw-agent;
# when the caller has no TTY the timeout kills the caller but orphans pinentry,
# causing a CPU storm. Check first, bail if not unlocked.
if ! command ${=_dotfiles_bw_timeout} rbw unlocked >/dev/null 2>&1; then
    [[ -o interactive ]] && printf '[rbw] vault locked — run: rbw unlock\n' >&2
    unset _dotfiles_bw_timeout
    return 0
fi

# Helper: timeout-wrapped lookup. Returns empty string on lock / miss / error.
# Uses `command` to dodge any user alias.
_dotfiles_bw_get() {
    command ${=_dotfiles_bw_timeout} rbw get "$1" 2>/dev/null || true
}

# Helper: fetch a named custom field from a Bitwarden item.
_dotfiles_bw_get_field() {
    command ${=_dotfiles_bw_timeout} rbw get --field "$1" "$2" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Tokens — uncomment + populate Bitwarden item as you migrate each one.
# Pattern: export NAME="$(_dotfiles_bw_get 'Bitwarden item title')"
# -----------------------------------------------------------------------------

export GITHUB_PERSONAL_ACCESS_TOKEN="$(_dotfiles_bw_get 'GitHub PAT')"

# Atlassian — shared across AKQA and Fiskars (same Atlassian account & token).
# Consumed by ~/.claude/scripts/atlassian-{akqa,fiskars}.sh MCP wrappers.
# URLs and username are non-secret, inlined. Token lives in Bitwarden item
# 'API Key - id.atlassian.com', custom field 'API Token - MCP'.
export ATLASSIAN_USERNAME="christian.brostrom@akqa.com"
export ATLASSIAN_API_TOKEN="$(_dotfiles_bw_get_field 'API Token - MCP' 'API Key - id.atlassian.com')"
export ATLASSIAN_FISKARS_JIRA_URL="https://fiskars.atlassian.net"
export ATLASSIAN_FISKARS_CONFLUENCE_URL="https://fiskars.atlassian.net/wiki"
export ATLASSIAN_AKQA_JIRA_URL="https://akqa-denmark.atlassian.net"
export ATLASSIAN_AKQA_CONFLUENCE_URL="https://akqa-denmark.atlassian.net/wiki"

# export OPENAI_API_KEY="$(_dotfiles_bw_get 'OpenAI API Key')"
# export ANTHROPIC_API_KEY="$(_dotfiles_bw_get 'Anthropic API Key')"

# Write cache for next terminal window (8h TTL, /tmp cleared on reboot)
_RBW_ENV_CACHE="${XDG_RUNTIME_DIR:-/tmp}/rbw-env-$UID.zsh"
{
    printf 'export GITHUB_PERSONAL_ACCESS_TOKEN=%q\n' "$GITHUB_PERSONAL_ACCESS_TOKEN"
    printf 'export ATLASSIAN_USERNAME=%q\n' "$ATLASSIAN_USERNAME"
    printf 'export ATLASSIAN_API_TOKEN=%q\n' "$ATLASSIAN_API_TOKEN"
    printf 'export ATLASSIAN_FISKARS_JIRA_URL=%q\n' "$ATLASSIAN_FISKARS_JIRA_URL"
    printf 'export ATLASSIAN_FISKARS_CONFLUENCE_URL=%q\n' "$ATLASSIAN_FISKARS_CONFLUENCE_URL"
    printf 'export ATLASSIAN_AKQA_JIRA_URL=%q\n' "$ATLASSIAN_AKQA_JIRA_URL"
    printf 'export ATLASSIAN_AKQA_CONFLUENCE_URL=%q\n' "$ATLASSIAN_AKQA_CONFLUENCE_URL"
} > "$_RBW_ENV_CACHE"
chmod 600 "$_RBW_ENV_CACHE"
unset _RBW_ENV_CACHE

unset -f _dotfiles_bw_get _dotfiles_bw_get_field
unset _dotfiles_bw_timeout
