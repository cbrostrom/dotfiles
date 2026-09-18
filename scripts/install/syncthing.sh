#!/usr/bin/env bash
# =============================================================================
# scripts/install/syncthing.sh — install Syncthing v2 as a user service
# =============================================================================
# Installs the Syncthing v2 binary into ~/.local/bin and wires a systemd user
# unit (cloudbro/server profiles). Idempotent: every step is guarded, so
# re-runs converge to the same state without duplication or clobbering.
#
# Does NOT do topology (device pairing, folder join) — those are per-host
# decisions. Set SYNCTHING_VERSION to pin; empty value = latest release.
# =============================================================================

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
TARGET="$BIN_DIR/syncthing"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT="$UNIT_DIR/syncthing.service"
SYNCTHING_VERSION="${SYNCTHING_VERSION:-}"

log() { printf '[syncthing-install] %s\n' "$*"; }
err() { printf '[syncthing-install] error: %s\n' "$*" >&2; }

# ── 1. Binary: install only when missing ─────────────────────────
# Never clobbers a newer/managed binary on re-run. Linux amd64 build
# from the official GitHub release tarball.
ARCH="$(uname -s)"
if [[ "$ARCH" != "Linux" ]]; then
    log "non-Linux host ($ARCH): brew manages syncthing — nothing to do"
    exit 0
fi
if [[ "$(uname -m)" != "x86_64" ]]; then
    err "unsupported arch: $(uname -m) (x86_64 only)"
    exit 1
fi

mkdir -p "$BIN_DIR"
if [[ ! -x "$TARGET" ]]; then
    if [[ -z "$SYNCTHING_VERSION" ]]; then
        URL="https://github.com/syncthing/syncthing/releases/latest/download/syncthing-linux-amd64-v2.tar.gz"
    else
        URL="https://github.com/syncthing/syncthing/releases/download/v${SYNCTHING_VERSION}/syncthing-linux-amd64-v2-${SYNCTHING_VERSION}.tar.gz"
    fi
    log "downloading: $URL"
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    curl -fsSL "$URL" | tar -xz -C "$TMP" --strip-components=1 syncthing/syncthing syncthing/syncthing.1 2>/dev/null \
        || { err "download/extract failed from $URL"; exit 1; }
    install -m 755 "$TMP/syncthing" "$TARGET"
    log "installed binary: $TARGET"
else
    log "binary already present: $TARGET"
fi

if ! "$TARGET" version >/dev/null 2>&1; then
    err "installed binary does not respond: $TARGET"
    exit 1
fi

# ── 2. systemd user unit: write only when content differs ────────
if ! command -v systemctl >/dev/null 2>&1 || \
   ! systemctl --user is-system-running >/dev/null 2>&1; then
    log "no user systemd session — skipping unit wiring (daemon can be"
    log "  started manually: $TARGET serve --no-browser)"
    exit 0
fi

mkdir -p "$UNIT_DIR"
EXPECTED="# Managed by dotfiles scripts/install/syncthing.sh — do not edit
[Unit]
Description=Syncthing (dotfiles-managed)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$TARGET serve --no-browser --no-restart --no-upgrade
Restart=on-failure

[Install]
WantedBy=default.target
"
if [[ ! -f "$UNIT" ]] || ! diff -q <(printf '%s\n' "$EXPECTED") "$UNIT" >/dev/null 2>&1; then
    printf '%s\n' "$EXPECTED" > "$UNIT"
    systemctl --user daemon-reload
    log "unit written: $UNIT"
else
    log "unit already matches expected content"
fi

# ── 3. Enable + start: guarded ─────────────────────────────────────
if ! systemctl --user is-enabled syncthing >/dev/null 2>&1; then
    systemctl --user enable syncthing
    log "unit enabled"
fi
if [[ "$(systemctl --user is-active syncthing)" != "active" ]]; then
    systemctl --user reset-failed syncthing 2>/dev/null || true
    systemctl --user start syncthing
fi

# ── 4. Linger: enable when off (survives logout) ──────────────────
USER_NAME="$(whoami)"
if [[ "$(loginctl show-user "$USER_NAME" -p Linger 2>/dev/null)" == "Linger=no" ]]; then
    sudo loginctl enable-linger "$USER_NAME" \
        || log "note: could not enable linger (needs sudo) — running until logout"
fi

# ── 5. Verify: fail fast on drift ─────────────────────────────────
sleep 3
if [[ "$(systemctl --user is-active syncthing)" != "active" ]]; then
    err "syncthing unit not active after start — check: journalctl --user -u syncthing"
    exit 1
fi
log "syncthing running: $($TARGET version | head -1)"
