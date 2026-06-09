#!/usr/bin/env bash
# =============================================================================
# modules/engram/sync.sh — sync local engram vaults to git
# =============================================================================
# Idempotent. Safe to run concurrently (flock guard). Called by:
#   - launchd reactive trigger (WatchPaths on engram.db-wal)
#   - launchd safety-net trigger (StartInterval=3600)
#   - dotfiles TUI menu → "Engram Sync"
#   - manual:  bash ~/dotfiles/modules/engram/sync.sh
#
# Environment overrides (rarely needed):
#   ENGRAM_SYNC_REPO     default ~/engram-sync
#   ENGRAM_SYNC_VAULTS   default "personal work" (space-separated)
#   ENGRAM_SYNC_PUSH     default 1 (set 0 to skip git push)
#   ENGRAM_BIN           default /opt/homebrew/bin/engram (Apple Silicon)
# =============================================================================

set -euo pipefail

ENGRAM_SYNC_VAULTS="${ENGRAM_SYNC_VAULTS:-personal work}"
ENGRAM_SYNC_PUSH="${ENGRAM_SYNC_PUSH:-1}"

# Platform-specific binary, vault root, and sync repo defaults.
if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    _win_home="/mnt/c/Users/${USER}"
    _default_bin="${_win_home}/go/bin/engram.exe"
    _default_vault_root="${_win_home}/.engram"
    # On WSL the vault dir IS the sync repo (git init'd by install/engram.sh)
    _default_sync_repo="${_default_vault_root}"
else
    _default_bin="$(command -v engram 2>/dev/null || true)"
    if [[ -z "$_default_bin" ]]; then
        for _p in "$HOME/go/bin/engram" /opt/homebrew/bin/engram /usr/local/bin/engram; do
            [[ -x "$_p" ]] && { _default_bin="$_p"; break; }
        done
    fi
    _default_vault_root="$HOME/.engram"
    _default_sync_repo="$HOME/engram-sync"
fi
ENGRAM_BIN="${ENGRAM_BIN:-${_default_bin}}"
ENGRAM_VAULT_ROOT="${ENGRAM_VAULT_ROOT:-${_default_vault_root}}"
ENGRAM_SYNC_REPO="${ENGRAM_SYNC_REPO:-${_default_sync_repo}}"
unset _win_home _default_bin _default_vault_root _default_sync_repo _p

# Platform-specific log/lock locations.
# macOS: ~/Library/* (canonical)
# Linux/WSL: XDG state + cache (FHS + XDG spec compliant)
case "$(uname -s)" in
    Darwin)
        DEFAULT_LOG="$HOME/Library/Logs/engram-sync.log"
        DEFAULT_LOCK="$HOME/Library/Caches/engram-sync.lock"
        ;;
    *)
        DEFAULT_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/engram-sync.log"
        DEFAULT_LOCK="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/engram-sync.lock"
        ;;
esac
LOG_FILE="${ENGRAM_SYNC_LOG:-$DEFAULT_LOG}"
LOCK_FILE="${ENGRAM_SYNC_LOCK:-$DEFAULT_LOCK}"

mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$LOCK_FILE")"

# Logging: write to file + stdout. Under launchd, StandardOutPath redirects
# stdout to the same file, so we dedupe by writing only to stdout when running
# under launchd (no controlling tty), and to both when run interactively.
log() {
    local line
    line="$(printf '[%s] %s' "$(date -u +%FT%TZ)" "$*")"
    if [[ -t 1 ]]; then
        echo "$line" | tee -a "$LOG_FILE"
    else
        echo "$line"
    fi
}
err() {
    local line
    line="$(printf '[%s] ERR: %s' "$(date -u +%FT%TZ)" "$*")"
    if [[ -t 2 ]]; then
        echo "$line" | tee -a "$LOG_FILE" >&2
    else
        echo "$line" >&2
    fi
}

# Concurrency guard: only one sync at a time. Non-blocking — silently exits if
# another sync is running (e.g. launchd reactive vs safety-net coinciding).
# Portable PID-file lock (macOS doesn't ship flock).
if [[ -f "$LOCK_FILE" ]]; then
    other_pid="$(cat "$LOCK_FILE" 2>/dev/null || echo "")"
    if [[ -n "$other_pid" ]] && kill -0 "$other_pid" 2>/dev/null; then
        log "another sync in progress (pid $other_pid) — exiting cleanly"
        exit 0
    fi
    # stale lock — previous run died without cleanup
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

if [[ ! -x "$ENGRAM_BIN" ]]; then
    err "engram binary not found at $ENGRAM_BIN — install first"
    exit 1
fi

if [[ ! -d "$ENGRAM_SYNC_REPO/.git" ]]; then
    err "$ENGRAM_SYNC_REPO is not a git repo — run module install first"
    exit 1
fi

cd "$ENGRAM_SYNC_REPO"

start_sha="$(git rev-parse HEAD 2>/dev/null || echo init)"
total_chunks=0

for vault in $ENGRAM_SYNC_VAULTS; do
    data_dir="${ENGRAM_VAULT_ROOT}/$vault"
    sub_dir="$ENGRAM_SYNC_REPO/$vault"

    if [[ ! -d "$data_dir" ]]; then
        log "skip vault=$vault — data dir $data_dir missing"
        continue
    fi
    mkdir -p "$sub_dir"

    log "sync vault=$vault data_dir=$data_dir"
    pushd "$sub_dir" >/dev/null

    # `engram sync --all` is idempotent: emits new chunk only when memories
    # have changed since last export. Output goes to ./.engram/chunks/.
    if out="$(ENGRAM_DATA_DIR="$data_dir" "$ENGRAM_BIN" sync --all 2>&1)"; then
        if echo "$out" | grep -q "Created chunk"; then
            chunk_id="$(echo "$out" | awk '/Created chunk/{print $3; exit}')"
            log "  ✓ vault=$vault new chunk=$chunk_id"
            total_chunks=$((total_chunks + 1))
        else
            log "  · vault=$vault no new memories"
        fi
    else
        err "  ✗ vault=$vault sync failed: $out"
    fi
    popd >/dev/null
done

if [[ $total_chunks -eq 0 ]] && git diff --quiet && git diff --cached --quiet; then
    log "no changes to commit"
    exit 0
fi

git add .
if git diff --cached --quiet; then
    log "nothing staged — exiting"
    exit 0
fi

host="$(hostname -s)"
git commit -m "sync: $total_chunks new chunk(s) from $host @ $(date -u +%FT%TZ)" >/dev/null
log "committed $(git rev-parse --short HEAD)"

_import_chunks() {
    for vault in $ENGRAM_SYNC_VAULTS; do
        local data_dir="${ENGRAM_VAULT_ROOT}/$vault"
        local sub_dir="$ENGRAM_SYNC_REPO/$vault"
        [[ -d "$data_dir" && -d "$sub_dir" ]] || continue
        if out="$(ENGRAM_DATA_DIR="$data_dir" "$ENGRAM_BIN" sync --import 2>&1)"; then
            log "  ↓ vault=$vault import ok"
        else
            err "  ✗ vault=$vault import failed: $out"
        fi
    done
}

if [[ "$ENGRAM_SYNC_PUSH" == "1" ]]; then
    # Multi-machine safe push: pull --rebase first to absorb other machines'
    # commits, then push. Retry up to 3x with exponential backoff (2s, 4s, 8s)
    # to survive transient races (two machines pushing within the same second).
    # Chunks have unique filenames (sha-tagged per device + timestamp), so
    # rebase always fast-forwards — no real conflicts possible in practice.
    push_ok=0
    for attempt in 1 2 3; do
        # Only pull --rebase if upstream tracking is set (not on first push).
        if git rev-parse '@{u}' >/dev/null 2>&1; then
            if ! git pull --rebase --autostash --quiet 2>>"$LOG_FILE"; then
                err "pull --rebase failed (attempt $attempt) — likely real conflict, manual fix needed"
                exit 1
            fi
            _import_chunks
        fi
        if git push --quiet 2>>"$LOG_FILE"; then
            log "pushed $(git rev-parse --short HEAD) (attempt $attempt)"
            push_ok=1
            break
        fi
        backoff=$((attempt * attempt * 2))
        log "push failed (attempt $attempt) — sleeping ${backoff}s before retry"
        sleep "$backoff"
    done
    if [[ $push_ok -ne 1 ]]; then
        err "push failed after 3 attempts — will retry on next trigger"
        exit 1
    fi
else
    log "push disabled (ENGRAM_SYNC_PUSH=0) — local commit only"
fi

end_sha="$(git rev-parse HEAD)"
[[ "$start_sha" != "$end_sha" ]] && log "done: $start_sha → $end_sha"
exit 0
