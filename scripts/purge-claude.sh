#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}[purge]${NC} $1"; }
warn() { echo -e "${RED}[purge]${NC} $1"; }

echo "🚀 Starting hard purge of Claude footprints..."

# 1. Remove home directories
TARGETS=(
    "$HOME/.claude"
    "$HOME/.config/claude"
)

for target in "${TARGETS[@]}"; do
    if [[ -d "$target" ]]; then
        info "Removing $target..."
        rm -rf "$target"
    else
        info "Skipping $target (not found)"
    fi
done

# 2. Remove potential binaries
BINARIES=(
    "$HOME/.local/bin/claude"
    "/usr/local/bin/claude"
)

for bin in "${BINARIES[@]}"; do
    if [[ -f "$bin" ]]; then
        info "Removing binary $bin..."
        rm -f "$bin"
    fi
done

info "✅ Claude purge complete."
