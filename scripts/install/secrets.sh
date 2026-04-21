#!/usr/bin/env bash
# =============================================================================
# scripts/install/secrets.sh — bootstrap encrypted secrets workflow
# =============================================================================
# Strategy:
#   1. age + sops for git-committable encrypted .env files
#   2. 1Password CLI (`op`) for runtime injection (never on disk)
#   3. ~/.local-secrets for legacy fallback (chmod 600 enforced)
#
# Usage:
#   ./scripts/install/secrets.sh init    # create age key + perms + recipient
#   ./scripts/install/secrets.sh check   # report current state
#   ./scripts/install/secrets.sh edit FILE
# =============================================================================

set -euo pipefail

AGE_KEY="$HOME/.config/sops/age/keys.txt"
SECRETS_FILE="$HOME/.local-secrets"

log()  { printf "\033[0;34m[secrets]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
err()  { printf "\033[0;31m[err]\033[0m %s\n" "$*" >&2; }

cmd_init() {
    if [[ -f "$SECRETS_FILE" ]]; then
        chmod 600 "$SECRETS_FILE"
        log "Set chmod 600 on $SECRETS_FILE"
    else
        warn "$SECRETS_FILE not present — copy .local-secrets.example first."
    fi

    command -v age >/dev/null 2>&1 || { err "age not installed. brew install age / apt install age"; exit 1; }
    command -v age-keygen >/dev/null 2>&1 || { err "age-keygen missing"; exit 1; }

    if [[ -f "$AGE_KEY" ]]; then
        log "age key already exists at $AGE_KEY"
    else
        mkdir -p "$(dirname "$AGE_KEY")"
        age-keygen -o "$AGE_KEY"
        chmod 600 "$AGE_KEY"
        log "Generated age key. Public recipient:"
        grep -E '^# public key:' "$AGE_KEY" | sed 's/^# public key: //'
    fi

    log "Add this machine's public key to .sops.yaml in repo, then encrypt secrets with sops."
    if ! command -v op >/dev/null 2>&1; then
        warn "1Password CLI (op) not installed — runtime secret injection unavailable."
        warn "  brew install --cask 1password-cli   # mac"
        warn "  see https://developer.1password.com/docs/cli/get-started/  # linux"
    fi
}

cmd_check() {
    [[ -f "$SECRETS_FILE" ]] && log "$SECRETS_FILE present ($(stat -f '%Lp' "$SECRETS_FILE" 2>/dev/null || stat -c '%a' "$SECRETS_FILE"))" || warn "$SECRETS_FILE missing"
    [[ -f "$AGE_KEY" ]]      && log "age key present" || warn "age key missing — run: $0 init"
    command -v sops >/dev/null 2>&1 && log "sops installed" || warn "sops missing"
    command -v op   >/dev/null 2>&1 && log "1Password CLI installed" || warn "op missing"
}

cmd_edit() {
    local file="${1:-}"
    [[ -z "$file" ]] && { err "usage: $0 edit <file.enc.yaml>"; exit 2; }
    command -v sops >/dev/null 2>&1 || { err "sops not installed"; exit 1; }
    SOPS_AGE_KEY_FILE="$AGE_KEY" sops "$file"
}

case "${1:-check}" in
    init)  cmd_init ;;
    check) cmd_check ;;
    edit)  shift; cmd_edit "$@" ;;
    *)     err "unknown subcommand: $1"; exit 2 ;;
esac
