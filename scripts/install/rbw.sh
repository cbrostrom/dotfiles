#!/usr/bin/env bash
# =============================================================================
# scripts/install/rbw.sh — install rbw (unofficial Bitwarden CLI) + pinentry
# =============================================================================
# Cross-platform: macOS (brew), Debian/Ubuntu (apt), Arch (pacman), Fedora,
# WSL (Linux package mgr), generic fallback (cargo).
#
# Writes ~/.config/rbw/config.json with platform-appropriate pinentry program
# only if the file does not already exist. Subsequent runs leave user edits
# untouched.
#
# Does NOT run `rbw login` — that is interactive and per-user. See README
# of this module for setup steps (or ask the user when first running).
# =============================================================================

set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/platform.sh"

RBW_EMAIL_DEFAULT="signup@christianbrostrom.com"
RBW_BASE_URL_DEFAULT="https://vault.superbro.dk"
RBW_LOCK_TIMEOUT_DEFAULT="28800"

# macOS rbw ignores XDG — uses platform data dir
if is_macos; then
    RBW_CONFIG_DIR="$HOME/Library/Application Support/rbw"
else
    RBW_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rbw"
fi
RBW_CONFIG_FILE="$RBW_CONFIG_DIR/config.json"

resolve_base_url() {
    # 1. Caller-supplied env wins
    if [[ -n "${RBW_BASE_URL:-}" ]]; then
        echo "$RBW_BASE_URL"
        return
    fi
    # 2. Existing config wins (don't clobber)
    if [[ -f "$RBW_CONFIG_FILE" ]]; then
        local existing
        existing=$(grep -oP '"base_url"\s*:\s*"\K[^"]+' "$RBW_CONFIG_FILE" 2>/dev/null || true)
        if [[ -n "$existing" ]]; then
            echo "$existing"
            return
        fi
    fi
    # 3. Interactive prompt (with default shown)
    local url
    if [[ -t 0 ]]; then
        read -r -p "Bitwarden base URL [$RBW_BASE_URL_DEFAULT]: " url
    fi
    echo "${url:-$RBW_BASE_URL_DEFAULT}"
}

install_rbw() {
    if has rbw; then
        ok "rbw already installed: $(command -v rbw)"
        return 0
    fi

    if is_macos; then
        if has brew; then
            log "installing rbw + pinentry-mac + coreutils via brew …"
            # coreutils provides `gtimeout` — env-secrets.zsh wraps rbw calls
            # in a 1s timeout to prevent shell-startup hang on locked vaults.
            brew install rbw pinentry-mac coreutils || warn "brew install rbw failed"
            brew install jorgelbg/tap/pinentry-touchid 2>/dev/null || warn "pinentry-touchid install failed (non-fatal)"
            return 0
        fi
    fi

    if is_debian; then
        log "installing rbw + pinentry-tty via apt …"
        if sudo apt-get install -y rbw pinentry-tty 2>/dev/null; then
            return 0
        fi
        warn "apt rbw missing or too old — falling back to cargo"
    fi

    if is_arch; then
        log "installing rbw + pinentry via pacman …"
        sudo pacman -S --noconfirm --needed rbw pinentry || warn "pacman install failed"
        return 0
    fi

    if is_fedora; then
        log "installing rbw via dnf …"
        sudo dnf install -y rbw pinentry || warn "dnf install failed"
        return 0
    fi

    # Cargo fallback (works everywhere with a Rust toolchain)
    if has cargo; then
        log "installing rbw via cargo (compile from source) …"
        cargo install rbw || warn "cargo install rbw failed"
    elif [[ -x "$HOME/.cargo/bin/cargo" ]]; then
        export PATH="$HOME/.cargo/bin:$PATH"
        cargo install rbw || warn "cargo install rbw failed"
    else
        err "no supported package manager and no cargo — install rustup first or rbw manually"
        return 1
    fi

    # Linux fallback also needs pinentry — try common names
    if is_linux && ! has pinentry-tty && ! has pinentry-curses && ! has pinentry; then
        if has apt-get; then
            sudo apt-get install -y pinentry-tty || warn "pinentry-tty install failed"
        elif has pacman; then
            sudo pacman -S --noconfirm --needed pinentry || warn "pinentry install failed"
        elif has dnf; then
            sudo dnf install -y pinentry || warn "pinentry install failed"
        else
            warn "no pinentry installed — rbw unlock will fail until you install one"
        fi
    fi
}

write_default_config() {
    local base_url
    base_url=$(resolve_base_url)

    if [[ -f "$RBW_CONFIG_FILE" ]]; then
        # Patch missing base_url into existing config without clobbering
        if ! grep -q '"base_url"' "$RBW_CONFIG_FILE"; then
            warn "rbw config missing base_url — patching with $base_url"
            local tmp
            tmp=$(mktemp)
            # Insert after opening brace
            sed "s|{|{\n    \"base_url\": \"$base_url\",|" "$RBW_CONFIG_FILE" > "$tmp" && mv "$tmp" "$RBW_CONFIG_FILE"
            chmod 600 "$RBW_CONFIG_FILE"
            ok "patched base_url → $base_url"
        else
            skip "rbw config exists ($RBW_CONFIG_FILE) — leaving untouched"
        fi
        return 0
    fi

    local pinentry_program
    if is_macos; then
        if has pinentry-touchid; then
            pinentry_program="pinentry-touchid"
        else
            pinentry_program="pinentry-mac"
        fi
    elif has pinentry-tty; then
        pinentry_program="pinentry-tty"
    elif has pinentry-curses; then
        pinentry_program="pinentry-curses"
    elif has pinentry; then
        pinentry_program="pinentry"
    else
        pinentry_program="pinentry-tty"
    fi

    mkdir -p "$RBW_CONFIG_DIR"
    cat > "$RBW_CONFIG_FILE" <<EOF
{
    "email": "$RBW_EMAIL_DEFAULT",
    "base_url": "$base_url",
    "lock_timeout": $RBW_LOCK_TIMEOUT_DEFAULT,
    "sync_interval": 3600,
    "pinentry": "$pinentry_program",
    "device_id": null
}
EOF
    chmod 600 "$RBW_CONFIG_FILE"
    ok "wrote rbw config → $RBW_CONFIG_FILE (pinentry=$pinentry_program)"
}

install_unlock_helper() {
    local unlock_script="${DOTFILES_DIR}/modules/rbw/rbw-unlock-if-locked.sh"
    [[ -f "${unlock_script}" ]] || { warn "rbw unlock helper not found — skipping"; return 0; }
    chmod +x "${unlock_script}"
    ok "rbw unlock helper executable → ${unlock_script}"
}

install_launchagent() {
    is_macos || return 0
    local plist_src="${DOTFILES_DIR}/modules/rbw/dk.brostrom.rbw-unlock.plist"
    local plist_dst="${HOME}/Library/LaunchAgents/dk.brostrom.rbw-unlock.plist"
    local unlock_script="${DOTFILES_DIR}/modules/rbw/rbw-unlock-if-locked.sh"
    [[ -f "${plist_src}" ]] || { warn "rbw unlock plist not found — skipping LaunchAgent"; return 0; }
    [[ -x "${unlock_script}" ]] || { warn "rbw unlock helper missing — run install_unlock_helper first"; return 0; }
    mkdir -p "$(dirname "${plist_dst}")"
    sed "s|__DOTFILES_DIR__|${DOTFILES_DIR}|g" "${plist_src}" > "${plist_dst}"
    launchctl unload "${plist_dst}" 2>/dev/null || true
    launchctl load "${plist_dst}" && ok "rbw-unlock LaunchAgent loaded (Touch ID at login)" || warn "launchctl load failed"
}

print_next_steps() {
    if has rbw && [[ -f "$RBW_CONFIG_FILE" ]]; then
        info "next steps (one-time, per machine):"
        info "  1. rbw login                    # authenticate with Bitwarden master password"
        info "  2. rbw unlock                   # one Touch ID tap → silent for 8h"
        info "  3. open a new terminal — env-secrets.zsh will populate \$GITHUB_PERSONAL_ACCESS_TOKEN etc."
        info "  4. restart Cursor / Claude — MCP servers pick up new env on launch"
    fi
}

install_rbw
write_default_config
install_unlock_helper
install_launchagent
print_next_steps
