#!/usr/bin/env bash
# Install the `plannotator` CLI binary required by the plannotator plugin.
# Idempotent — skips if already on PATH.
#
# The Claude Code plugin (backnotprop/plannotator) provides hooks + slash
# commands but relies on the `plannotator` binary being executable.
# Released by Plannotator with SHA256 + SLSA provenance.

set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[plannotator]${NC} $1"; }
log_success() { echo -e "${GREEN}[plannotator]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[plannotator]${NC} $1"; }

if command -v plannotator >/dev/null 2>&1; then
    log_info "plannotator already installed: $(command -v plannotator)"
    exit 0
fi

case "$(uname -s)" in
    Darwin|Linux)
        log_info "Installing plannotator binary via plannotator.ai install script…"
        if curl -fsSL https://plannotator.ai/install.sh | bash; then
            log_success "plannotator installed"
        else
            log_warning "plannotator install failed (non-fatal). Run manually: curl -fsSL https://plannotator.ai/install.sh | bash"
            exit 0
        fi
        ;;
    *)
        log_warning "Unsupported platform $(uname -s) — install plannotator manually from https://plannotator.ai"
        exit 0
        ;;
esac
