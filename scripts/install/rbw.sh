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
RBW_LOCK_TIMEOUT_DEFAULT="3600"
# macOS rbw ignores XDG — uses platform data dir
if is_macos; then
    RBW_CONFIG_DIR="$HOME/Library/Application Support/rbw"
else
    RBW_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rbw"
fi
RBW_CONFIG_FILE="$RBW_CONFIG_DIR/config.json"

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
    if [[ -f "$RBW_CONFIG_FILE" ]]; then
        skip "rbw config exists ($RBW_CONFIG_FILE) — leaving untouched"
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
    "base_url": "$RBW_BASE_URL_DEFAULT",
    "lock_timeout": $RBW_LOCK_TIMEOUT_DEFAULT,
    "sync_interval": 3600,
    "pinentry": "$pinentry_program",
    "device_id": null
}
EOF
    chmod 600 "$RBW_CONFIG_FILE"
    ok "wrote rbw config → $RBW_CONFIG_FILE (pinentry=$pinentry_program)"
}

print_next_steps() {
    if has rbw && [[ -f "$RBW_CONFIG_FILE" ]]; then
        info "next steps (one-time, per machine):"
        info "  1. rbw login                    # authenticate with Bitwarden master password"
        info "  2. rbw unlock                   # unlock the vault (cached for $RBW_LOCK_TIMEOUT_DEFAULT seconds)"
        info "  3. open a new terminal — env-secrets.zsh will populate \$GITHUB_PERSONAL_ACCESS_TOKEN etc."
        info "  4. restart Cursor / Claude — MCP servers pick up new env on launch"
    fi
}

install_rbw
write_default_config
print_next_steps
