#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

if command -v cargo >/dev/null 2>&1 || [[ -x "$HOME/.cargo/bin/cargo" ]]; then
    ok "rustup / cargo already installed: $(command -v cargo 2>/dev/null || echo "$HOME/.cargo/bin/cargo")"
    exit 0
fi

log "installing rustup (stable, minimal profile) …"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path \
    || { warn "rustup install failed (non-fatal)"; exit 0; }
export PATH="$HOME/.cargo/bin:$PATH"
ok "rustup installed → cargo $(cargo --version 2>/dev/null || echo 'ready')"
