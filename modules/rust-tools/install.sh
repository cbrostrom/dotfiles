#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

LEAN_CTX_VERSION="3.5.21"
INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR"

install_lean_ctx_binary() {
    local arch os_tag
    arch="$(uname -m)"
    case "$(uname -s)-${arch}" in
        Linux-x86_64)  os_tag="x86_64-unknown-linux-musl" ;;
        Linux-aarch64) os_tag="aarch64-unknown-linux-musl" ;;
        Darwin-arm64)  os_tag="aarch64-apple-darwin" ;;
        Darwin-x86_64) os_tag="x86_64-apple-darwin" ;;
        *)
            warn "no prebuilt lean-ctx for $(uname -s)-${arch} — falling back to cargo install"
            return 1
            ;;
    esac

    local url="https://github.com/yvgude/lean-ctx/releases/download/v${LEAN_CTX_VERSION}/lean-ctx-${os_tag}.tar.gz"
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    log "downloading lean-ctx ${LEAN_CTX_VERSION} (${os_tag}) …"
    if curl -fsSL "$url" | tar -xz -C "$tmp"; then
        install -m 755 "$tmp/lean-ctx" "$INSTALL_DIR/lean-ctx"
        ok "lean-ctx ${LEAN_CTX_VERSION} installed → ${INSTALL_DIR}/lean-ctx"
        return 0
    else
        warn "binary download failed — falling back to cargo install"
        return 1
    fi
}

# lean-ctx
if command -v lean-ctx >/dev/null 2>&1; then
    ok "lean-ctx already installed: $(command -v lean-ctx)"
else
    if ! install_lean_ctx_binary; then
        # Fallback: cargo compile (slow, but works on exotic arches)
        if ! command -v cargo >/dev/null 2>&1; then
            if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
                export PATH="$HOME/.cargo/bin:$PATH"
            else
                log "installing rustup (minimal stable toolchain) …"
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
                    | sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path \
                    || { warn "rustup install failed (non-fatal)"; exit 0; }
                export PATH="$HOME/.cargo/bin:$PATH"
            fi
        fi
        cargo install lean-ctx 2>/dev/null || warn "lean-ctx install failed (non-fatal)"
        ok "lean-ctx ready: $(command -v lean-ctx 2>/dev/null || echo 'not found')"
    fi
fi
