#!/usr/bin/env bash
# =============================================================================
# scripts/install/engram.sh — install engram + wire up local stdio + git sync
# =============================================================================
# Idempotent. Cross-platform (macOS launchd + Linux/WSL systemd-user). Steps:
#   1) Ensure `engram` binary present
#       - Darwin: brew tap install
#       - Linux:  cargo install --git (no prebuilt linux releases yet)
#   2) Ensure ~/engram-sync clone exists with correct remote
#   3) Render & install scheduler:
#       - Darwin: LaunchAgent (WatchPaths + StartInterval)
#       - Linux:  systemd-user .service + .timer + .path
#   4) Load/enable the scheduler
#
# Re-running is safe.
# =============================================================================

set -euo pipefail

. "${DOTFILES_DIR:-$HOME/dotfiles}/modules/_lib/log.sh"

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
SYNC_REPO="$HOME/engram-sync"
GIT_URL="git@github.com:cbrostrom/engram.git"
SYNC_SH="$DOTFILES_DIR/modules/engram/sync.sh"
OS="$(uname -s)"

# -------- 1) binary --------
install_engram_binary() {
    if command -v engram >/dev/null 2>&1; then
        ok "engram already on PATH: $(command -v engram) ($(engram version 2>/dev/null | head -1))"
        return 0
    fi

    case "$OS" in
        Darwin)
            if command -v brew >/dev/null 2>&1; then
                log "installing engram via Homebrew tap …"
                brew install gentleman-programming/tap/engram || warn "brew install engram failed"
            else
                warn "Homebrew not found — install engram manually: https://github.com/Gentleman-Programming/engram"
            fi
            ;;
        Linux)
            if command -v cargo >/dev/null 2>&1; then
                log "installing engram via cargo install --git …"
                log "(no prebuilt Linux binaries yet — building from source, takes ~5min)"
                cargo install --git https://github.com/Gentleman-Programming/engram engram \
                    || warn "cargo install engram failed — check network and rust toolchain"
            else
                warn "cargo not found. Install rustup first:"
                warn "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
                warn "  then re-run: bash $DOTFILES_DIR/scripts/install/engram.sh"
            fi
            ;;
        *)
            warn "unsupported platform $OS — install engram manually"
            ;;
    esac

    if command -v engram >/dev/null 2>&1; then
        ok "engram available: $(command -v engram) ($(engram version 2>/dev/null | head -1))"
    else
        warn "engram still not on PATH — module will be partially configured"
    fi
}

# -------- 2) ~/engram-sync repo --------
setup_sync_repo() {
    if [[ -d "$SYNC_REPO/.git" ]]; then
        local current_remote
        current_remote="$(git -C "$SYNC_REPO" remote get-url origin 2>/dev/null || echo "")"
        if [[ "$current_remote" != "$GIT_URL" ]]; then
            warn "$SYNC_REPO origin mismatch (got $current_remote, expected $GIT_URL) — leaving as-is"
        else
            ok "$SYNC_REPO already initialized"
        fi
    else
        log "cloning $GIT_URL → $SYNC_REPO …"
        if ! git clone "$GIT_URL" "$SYNC_REPO" 2>&1; then
            warn "clone failed — initializing empty repo (push later when ready)"
            mkdir -p "$SYNC_REPO/personal" "$SYNC_REPO/work"
            git -C "$SYNC_REPO" init -b main >/dev/null
            git -C "$SYNC_REPO" remote add origin "$GIT_URL" 2>/dev/null || true
        fi
    fi

    git -C "$SYNC_REPO" config push.autoSetupRemote true
}

# -------- 3a) macOS LaunchAgent --------
install_launchd_agent() {
    local plist_src="$DOTFILES_DIR/modules/engram/dk.brostrom.engram-sync.plist"
    local plist_dst="$HOME/Library/LaunchAgents/dk.brostrom.engram-sync.plist"
    local label="dk.brostrom.engram-sync"

    [[ -f "$plist_src" ]] || { err "plist template missing: $plist_src"; return 1; }
    [[ -x "$SYNC_SH" ]] || chmod +x "$SYNC_SH"

    mkdir -p "$(dirname "$plist_dst")" "$HOME/Library/Logs" "$HOME/Library/Caches"

    sed -e "s#__HOME__#$HOME#g" \
        -e "s#__SYNC_SH__#$SYNC_SH#g" \
        "$plist_src" > "$plist_dst"
    ok "rendered $plist_dst"

    if launchctl list "$label" >/dev/null 2>&1; then
        log "reloading existing LaunchAgent $label …"
        launchctl unload "$plist_dst" 2>/dev/null || true
    fi
    if launchctl load "$plist_dst" 2>&1; then
        ok "LaunchAgent loaded — reactive (WatchPaths) + hourly safety-net active"
    else
        warn "launchctl load failed — fix and rerun: launchctl load $plist_dst"
    fi
}

# -------- 3b) Linux systemd-user units --------
install_systemd_user() {
    local unit_src_dir="$DOTFILES_DIR/modules/engram/"
    local unit_dst_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    local units=(engram-sync.service engram-sync.timer engram-sync.path)

    if ! command -v systemctl >/dev/null 2>&1; then
        warn "systemctl not found — engram sync scheduler not installed"
        warn "  WSL? Enable systemd: edit /etc/wsl.conf → [boot]\\nsystemd=true → wsl --shutdown"
        return 1
    fi

    if ! systemctl --user status >/dev/null 2>&1; then
        warn "systemd --user not available. On WSL: enable systemd in /etc/wsl.conf, then wsl --shutdown"
        warn "  also: loginctl enable-linger \$USER  (so timers run after logout)"
        return 1
    fi

    [[ -x "$SYNC_SH" ]] || chmod +x "$SYNC_SH"
    mkdir -p "$unit_dst_dir"

    for unit in "${units[@]}"; do
        local src="$unit_src_dir/$unit"
        local dst="$unit_dst_dir/$unit"
        [[ -f "$src" ]] || { err "unit template missing: $src"; return 1; }
        sed -e "s#__SYNC_SH__#$SYNC_SH#g" "$src" > "$dst"
        ok "rendered $dst"
    done

    log "reloading systemd-user daemon …"
    systemctl --user daemon-reload

    # Enable timer (for hourly safety net) + path (for reactive trigger).
    # Service is triggered by the others, not enabled directly.
    systemctl --user enable --now engram-sync.timer engram-sync.path
    ok "systemd-user units enabled — reactive (.path) + hourly (.timer) active"

    # Linger reminder
    if ! loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
        warn "linger NOT enabled — timers stop when you log out. Fix:"
        warn "  sudo loginctl enable-linger $USER"
    fi
}

# -------- 4) summary --------
print_summary() {
    log "engram setup complete"
    info "  binary      : $(command -v engram 2>/dev/null || echo 'not found')"
    info "  data dirs   : ~/.engram/{personal,work}"
    info "  sync repo   : $SYNC_REPO"
    case "$OS" in
        Darwin)
            info "  scheduler   : launchd (dk.brostrom.engram-sync)"
            info "  log file    : ~/Library/Logs/engram-sync.log"
            ;;
        Linux)
            info "  scheduler   : systemd-user (engram-sync.{service,timer,path})"
            info "  log file    : ${XDG_STATE_HOME:-~/.local/state}/engram-sync.log"
            info "  inspect     : systemctl --user status engram-sync.timer engram-sync.path"
            info "  journal     : journalctl --user -u engram-sync.service"
            ;;
    esac
    info "  manual sync : dotfiles → menu → 'Engram Sync', or bash $SYNC_SH"
}

# -------- main --------
install_engram_binary
setup_sync_repo
case "$OS" in
    Darwin) install_launchd_agent ;;
    Linux)  install_systemd_user  ;;
    *)      warn "unsupported OS $OS — only binary install attempted" ;;
esac
print_summary
