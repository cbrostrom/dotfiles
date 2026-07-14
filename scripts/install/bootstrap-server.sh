#!/usr/bin/env bash
# =============================================================================
# scripts/install/bootstrap-server.sh — one-shot opencode + dotfiles setup
#                                        for headless Linux servers (server-headless profile)
# =============================================================================
# Usage (run on the server, or pipe via SSH):
#   bash bootstrap-server.sh
#   # or from mac:
#   ssh superbro 'bash -s' < scripts/install/bootstrap-server.sh
#
# What it does:
#   1. Clones dotfiles (if not already at ~/dotfiles)
#   2. Installs Node.js (if missing) — needed for npx tools
#   3. Installs OpenCode CLI
#   4. Runs dotfiles bootstrap with server-headless profile
#
# Idempotent — safe to re-run.
# =============================================================================

set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-git@github.com:backnotprop/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
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

# ── 2. Node.js ───────────────────────────────────────────────────────────────
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

# ── 3. RTK (token compression for shell output) ────────────────────────────
if command -v rtk >/dev/null 2>&1; then
    ok "rtk already installed"
else
    log "installing rtk (token compression)"
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    if ! grep -q '$HOME/.local/bin' "$HOME/.profile" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
    fi
    ok "rtk installed"
fi
# Install OpenCode plugin (auto-rewrites bash commands via tool.execute.before)
if command -v rtk >/dev/null 2>&1; then
    rtk init -g --opencode 2>/dev/null && ok "rtk opencode plugin installed" || warn "rtk opencode plugin install failed (non-fatal)"
fi

# ── 4. OpenCode CLI ─────────────────────────────────────────────────────────
if command -v opencode >/dev/null 2>&1; then
    ok "opencode already installed: $(opencode --version 2>/dev/null || echo 'unknown')"
else
    log "installing OpenCode CLI"
    curl -fsSL https://opencode.ai/install | bash
    ok "opencode installed"
fi

# ── 5. Dotfiles bootstrap ────────────────────────────────────────────────────
log "running dotfiles bootstrap (profile: server-headless)"
cd "$DOTFILES_DIR"
PROFILE=server-headless bash bootstrap.sh --only=symlinks,opencode

# ── 6. Done ───────────────────────────────────────────────────────────────────
ok "bootstrap complete"
echo ""
echo "Next steps:"
echo "  1. Set API keys in ~/.local-secrets (OpenRouter, GitHub, etc.)"
echo "  2. Ensure Tailscale is enrolled (tailscale up)"
echo "  3. cd ~ && opencode → /connect → pick provider → /models → select model"
