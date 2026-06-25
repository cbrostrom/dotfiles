#!/usr/bin/env bash
# =============================================================================
# scripts/install/bootstrap-server.sh — one-shot Claude Code + dotfiles setup
#                                        for headless Linux servers (server-headless profile)
# =============================================================================
# Usage (run on the server, or pipe via SSH):
#   bash bootstrap-server.sh
#   # or from mac:
#   ssh superbro 'bash -s' < scripts/install/bootstrap-server.sh
#
# What it does:
#   1. Clones dotfiles (if not already at ~/dotfiles)
#   2. Installs Go (if missing) — needed for engram + lean-ctx
#   3. Installs engram MCP binary
#   4. Installs lean-ctx binary (cargo)
#   5. Installs Node.js (if missing) — needed for Claude Code + npx MCPs
#   6. Installs Claude Code CLI
#   7. Runs dotfiles bootstrap with server-headless profile
#   8. Registers Claude Code MCP servers
#
# Idempotent — safe to re-run.
# =============================================================================

set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-git@github.com:backnotprop/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
GO_VERSION="${GO_VERSION:-1.22.4}"
NODE_VERSION="${NODE_VERSION:-20}"

log()  { printf "\033[0;34m[bootstrap]\033[0m %s\n" "$*"; }
ok()   { printf "\033[0;32m[ok]\033[0m %s\n" "$*"; }
warn() { printf "\033[0;33m[warn]\033[0m %s\n" "$*" >&2; }
die()  { printf "\033[0;31m[error]\033[0m %s\n" "$*" >&2; exit 1; }

# ── 1. Dotfiles ──────────────────────────────────────────────────────────────
if [[ -d "$DOTFILES_DIR/.git" ]]; then
    ok "dotfiles already at $DOTFILES_DIR"
else
    log "cloning dotfiles → $DOTFILES_DIR"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# ── 2. Go ─────────────────────────────────────────────────────────────────────
if command -v go >/dev/null 2>&1; then
    ok "go already installed: $(go version)"
else
    log "installing Go $GO_VERSION"
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)  GO_ARCH="amd64" ;;
        aarch64) GO_ARCH="arm64" ;;
        *)        die "unsupported arch: $ARCH" ;;
    esac
    GO_TAR="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    curl -fsSL "https://go.dev/dl/$GO_TAR" -o "/tmp/$GO_TAR"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "/tmp/$GO_TAR"
    rm "/tmp/$GO_TAR"
    export PATH="/usr/local/go/bin:$PATH"
    # Persist in .profile if not already there
    if ! grep -q '/usr/local/go/bin' "$HOME/.profile" 2>/dev/null; then
        echo 'export PATH="/usr/local/go/bin:$PATH"' >> "$HOME/.profile"
        echo 'export PATH="$HOME/go/bin:$PATH"' >> "$HOME/.profile"
    fi
    ok "go $GO_VERSION installed"
fi
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"

# ── 3. Engram ─────────────────────────────────────────────────────────────────
if command -v engram >/dev/null 2>&1; then
    ok "engram already installed"
else
    log "installing engram MCP binary"
    go install github.com/Gentleman-Programming/engram/cmd/engram@latest
    ok "engram installed"
fi

# ── 4. Rust toolchain ────────────────────────────────────────────────────────
if command -v cargo >/dev/null 2>&1 || [[ -x "$HOME/.cargo/bin/cargo" ]]; then
    ok "cargo already installed"
else
    log "installing Rust toolchain"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    source "$HOME/.cargo/env"
    ok "rust installed"
fi
export PATH="$HOME/.cargo/bin:$PATH"

# ── 5. Node.js ───────────────────────────────────────────────────────────────
if command -v node >/dev/null 2>&1; then
    ok "node already installed: $(node --version)"
else
    log "installing Node.js $NODE_VERSION via nvm"
    if [[ ! -d "$HOME/.nvm" ]]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    fi
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    nvm install "$NODE_VERSION"
    nvm use "$NODE_VERSION"
    ok "node $(node --version) installed"
fi

# ── 6. Claude Code CLI ───────────────────────────────────────────────────────
if command -v claude >/dev/null 2>&1; then
    ok "claude already installed: $(claude --version 2>/dev/null || echo 'unknown')"
else
    log "installing Claude Code CLI"
    npm install -g @anthropic-ai/claude-code
    ok "claude installed"
fi

# ── 7. Dotfiles bootstrap ────────────────────────────────────────────────────
log "running dotfiles bootstrap (profile: server-headless)"
cd "$DOTFILES_DIR"
PROFILE=server-headless bash bootstrap.sh --only=symlinks,claude-settings,mcp-servers,claude-plugins

# ── 8. Done ───────────────────────────────────────────────────────────────────
ok "bootstrap complete"
echo ""
echo "Next steps:"
echo "  1. Set ANTHROPIC_API_KEY in ~/.local-secrets"
echo "  2. Set GITHUB_PERSONAL_ACCESS_TOKEN in ~/.local-secrets"
echo "  3. Ensure Tailscale is enrolled (tailscale up)"
echo "  4. Verify: claude mcp list"
echo "  5. Test:   claude --no-mcp 'echo hello'"
