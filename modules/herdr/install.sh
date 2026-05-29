#!/usr/bin/env bash
# =============================================================================
# modules/herdr/install.sh — install herdr + optional autostart
# =============================================================================
# Opt-in per machine: add "herdr" to ~/.config/dotfiles/modules.conf
# Autostart opt-in:   add "herdr-autostart" to ~/.config/dotfiles/modules.conf
# =============================================================================
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/config.sh"
. "$DOTFILES_DIR/modules/_lib/platform.sh"

# ── 0) directories ────────────────────────────────────────────────────────────
mkdir -p \
    "$HOME/.config/herdr" \
    "$HOME/.herdr/worktrees" \
    "$HOME/.herdr/sessions" \
    "${XDG_STATE_HOME:-$HOME/.local/state}/herdr"

# ── 1) binary ─────────────────────────────────────────────────────────────────
if command -v herdr >/dev/null 2>&1; then
    ok "herdr already installed: $(command -v herdr) ($(herdr --version 2>/dev/null | head -1))"
else
    log "installing herdr …"
    if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        brew install herdr >/dev/null && ok "herdr installed via brew"
    else
        curl -fsSL https://herdr.dev/install.sh | sh \
            && ok "herdr installed" \
            || { warn "herdr install failed (non-fatal)"; exit 0; }
    fi
fi

# ── 2) Claude Code integration ────────────────────────────────────────────────
if command -v herdr >/dev/null 2>&1; then
    if herdr integration status 2>/dev/null | grep -q "claude.*up.to.date\|claude.*installed" 2>/dev/null; then
        ok "herdr claude integration already installed"
    else
        log "installing herdr claude integration …"
        herdr integration install claude 2>/dev/null \
            && ok "herdr claude integration installed" \
            || warn "herdr integration install failed (non-fatal)"
    fi
fi

# ── 3) config symlink ─────────────────────────────────────────────────────────
# We pre-created ~/.config/herdr above; replace it with a symlink to dotfiles.
HERDR_CONFIG_SRC="$DOTFILES_DIR/.config/herdr"
HERDR_CONFIG_DST="$HOME/.config/herdr"
if [[ -d "$HERDR_CONFIG_SRC" ]]; then
    if [[ -L "$HERDR_CONFIG_DST" ]]; then
        ok "herdr config symlink already present"
    else
        # Remove the empty dir we just mkdir'd (or any stale empty dir)
        if [[ -d "$HERDR_CONFIG_DST" && ! -L "$HERDR_CONFIG_DST" ]]; then
            if [[ -z "$(ls -A "$HERDR_CONFIG_DST" 2>/dev/null)" ]]; then
                rmdir "$HERDR_CONFIG_DST"
            else
                warn "~/.config/herdr has existing files — skipping symlink (manual config preserved)"
                HERDR_CONFIG_SRC=""  # prevent symlink below
            fi
        fi
        if [[ -n "$HERDR_CONFIG_SRC" ]]; then
            ln -sf "$HERDR_CONFIG_SRC" "$HERDR_CONFIG_DST"
            ok "herdr config symlinked → $HERDR_CONFIG_DST"
        fi
    fi
fi

# ── 4) autostart (opt-in via modules.conf: herdr-autostart) ───────────────────

_install_launchd() {
    local plist_dst="$HOME/Library/LaunchAgents/dev.herdr.server.plist"
    local herdr_bin
    herdr_bin="$(command -v herdr)"
    mkdir -p "$(dirname "$plist_dst")" "$HOME/Library/Logs"
    cat > "$plist_dst" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>             <string>dev.herdr.server</string>
    <key>ProgramArguments</key> <array><string>${herdr_bin}</string><string>server</string></array>
    <key>RunAtLoad</key>         <true/>
    <key>KeepAlive</key>         <true/>
    <key>StandardOutPath</key>   <string>${HOME}/Library/Logs/herdr.log</string>
    <key>StandardErrorPath</key> <string>${HOME}/Library/Logs/herdr.log</string>
</dict>
</plist>
EOF
    launchctl unload "$plist_dst" 2>/dev/null || true
    launchctl load "$plist_dst" && ok "herdr LaunchAgent loaded (autostart)" \
        || warn "launchctl load failed (non-fatal)"
}

_install_systemd() {
    if ! command -v systemctl >/dev/null 2>&1 || ! systemctl --user status >/dev/null 2>&1; then
        warn "systemd-user not available — skipping autostart (WSL: enable with [boot] systemd=true)"
        return 0
    fi
    local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    local herdr_bin
    herdr_bin="$(command -v herdr)"
    mkdir -p "$unit_dir"
    cat > "$unit_dir/herdr.service" <<EOF
[Unit]
Description=Herdr terminal session server
After=default.target

[Service]
ExecStart=${herdr_bin} server
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now herdr.service 2>/dev/null \
        && ok "herdr systemd-user service enabled (autostart)" \
        || warn "systemd enable failed (non-fatal)"
}

autostart_state="$(config_module_state "herdr-autostart" "false")"
if [[ "$autostart_state" == "enabled" ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
        _install_launchd
    else
        _install_systemd
    fi
fi
