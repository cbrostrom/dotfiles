#!/usr/bin/env bash
# =============================================================================
# scripts/install/higgins.sh — install the higgins vault CLI from source
# =============================================================================
# Higgins is stdlib-only Python living in ~/dotfiles/higgins (entry point
# `python3 -m higgins.cli`). This script creates a venv, installs nothing into
# it (stdlib only), and writes a `higgins` wrapper into ~/.local/bin.
#
# Works on macOS and Linux.
#
# Idempotent: rewrites the binary on every run.
# =============================================================================

# Higgins installer — unified Go binary with Python fallback.
# Primary: build the Go CLI from ~/Projects/private/higgins (memory
# consolidation P1+ devices live there: higgins ledger / duckdb). Fallback:
# legacy stdlib-only Python CLI in ~/dotfiles/higgins (entry point
# `python3 -m higgins.cli`) when the Go repo is unavailable.
#
# Works on macOS and Linux. Idempotent.
# =============================================================================

set -euo pipefail

GO_SRC="${HIGGINS_GO_SRC:-$HOME/Projects/private/higgins}"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HIGGINS_SRC="$DOTFILES_DIR/higgins"
VENV_DIR="${HIGGINS_VENV_DIR:-$HOME/.local/share/higgins-venv}"
BIN_DIR="$HOME/.local/bin"
WRAPPER="$BIN_DIR/higgins"

log() { printf '[higgins-install] %s\n' "$*"; }
err() { printf '[higgins-install] error: %s\n' "$*" >&2; }

mkdir -p "$BIN_DIR"

# ── Primary: Go binary build ──────────────────────────────────────
if command -v go >/dev/null 2>&1 && [[ -d "$GO_SRC" ]]; then
    log "building Go higgins from $GO_SRC"
    (cd "$GO_SRC" && go build -o "$WRAPPER")
    chmod +x "$WRAPPER"
    # macOS: ad-hoc re-sign so Gatekeeper does not SIGKILL on exec after copy.
    if command -v codesign >/dev/null 2>&1; then
        codesign -s - -f "$WRAPPER" >/dev/null 2>&1 || true
    fi
    log "installed Go binary: $WRAPPER"
    if "$WRAPPER" status >/dev/null 2>&1; then
        log "higgins CLI responds"
    else
        log "note: higgins status returned non-zero (vault may not be initialized yet)"
    fi
    exit 0
fi

# ── Fallback: legacy Python CLI wrapper ──────────────────────────
log "Go source not found at $GO_SRC — falling back to legacy Python CLI"
if [[ ! -f "$HIGGINS_SRC/cli.py" ]]; then
    err "source not found: $HIGGINS_SRC/cli.py"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    err "python3 not found — install it first (Debian: apt install python3 python3-venv)"
    exit 1
fi

# tomllib requires Python 3.11+.
if ! python3 -c 'import tomllib' >/dev/null 2>&1; then
    err "python3 too old — higgins needs 3.11+ (tomllib)"
    exit 1
fi

# Create the venv only when missing or broken.
if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    log "creating venv at $VENV_DIR"
    mkdir -p "$(dirname "$VENV_DIR")"
    python3 -m venv "$VENV_DIR"
fi

mkdir -p "$BIN_DIR"
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
export PYTHONPATH="\${PYTHONPATH:+$PYTHONPATH:}$HIGGINS_SRC"
exec "$VENV_DIR/bin/python" -m higgins.cli "\$@"
EOF
chmod +x "$WRAPPER"
log "installed wrapper: $WRAPPER (venv: $VENV_DIR, src: $HIGGINS_SRC)"
if "$WRAPPER" status >/dev/null 2>&1; then
    log "higgins CLI responds"
else
    log "note: higgins status returned non-zero (vault may not be initialized yet)"
fi
