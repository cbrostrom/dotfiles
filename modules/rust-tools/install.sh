#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

# 1. Toolchain
if ! command -v cargo >/dev/null 2>&1; then
    if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
        export PATH="$HOME/.cargo/bin:$PATH"
    else
        log "installing rustup (minimal stable toolchain) …"
        if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
            | sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path; then
            export PATH="$HOME/.cargo/bin:$PATH"
            ok "rustup installed: $(command -v cargo 2>/dev/null || echo 'not on PATH')"
        else
            warn "rustup install failed (non-fatal)"
            exit 0
        fi
    fi
fi

# 2. Cargo tools
if command -v cargo >/dev/null 2>&1; then
    if command -v lean-ctx >/dev/null 2>&1; then
        ok "lean-ctx already installed: $(command -v lean-ctx)"
    else
        log "cargo install lean-ctx …"
        cargo install lean-ctx 2>/dev/null || warn "lean-ctx install failed (non-fatal)"
        ok "lean-ctx ready: $(command -v lean-ctx 2>/dev/null || echo 'not found')"
    fi
fi
