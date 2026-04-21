#!/usr/bin/env bash
# Recursively symlink all files and subdirectories from source to target using relative paths
# Usage: ./symlink-dir.sh <source_dir> <target_dir>
# Cross-platform compatible: macOS, Linux, WSL2
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $# -ne 2 ]]; then
    log_error "Usage: $0 <source_dir> <target_dir>"
    exit 1
fi

# Cross-platform realpath
if command -v realpath >/dev/null 2>&1; then
    SRC=$(realpath "$1")
    DST=$(realpath "$2")
else
    # Fallback for systems without realpath
    SRC=$(cd "$1" && pwd)
    DST=$(cd "$2" 2>/dev/null && pwd || echo "$2")
fi

if [[ ! -d "$SRC" ]]; then
    log_error "Source directory does not exist: $SRC"
    exit 1
fi
mkdir -p "$DST"

symlink_item() {
    local src_item="$1"
    local dst_item="$2"
    if [[ -d "$src_item" ]]; then
        mkdir -p "$dst_item"
        for item in "$src_item"/*; do
            [[ -e "$item" ]] || continue
            symlink_item "$item" "$dst_item/$(basename "$item")"
        done
    else
        if [[ -L "$dst_item" || -e "$dst_item" ]]; then
            log_warning "Skipping existing: $dst_item"
        else
            # Cross-platform relative path calculation
            local rel_src
            if command -v realpath >/dev/null 2>&1; then
                rel_src=$(realpath --relative-to="$(dirname "$dst_item")" "$src_item" 2>/dev/null || echo "$src_item")
            elif command -v python3 >/dev/null 2>&1; then
                rel_src=$(python3 -c "import os.path; print(os.path.relpath('$src_item', os.path.dirname('$dst_item')))" 2>/dev/null || echo "$src_item")
            elif command -v node >/dev/null 2>&1; then
                rel_src=$(node -e "const path = require('path'); console.log(path.relative(path.dirname('$dst_item'), '$src_item'))" 2>/dev/null || echo "$src_item")
            else
                rel_src="$src_item"
                log_warning "Using absolute path (install realpath, python3, or node for relative paths)"
            fi
            ln -s "$rel_src" "$dst_item"
            log_success "Linked: $dst_item -> $rel_src"
        fi
    fi
}

log_info "Symlinking directory: $SRC -> $DST"
symlink_item "$SRC" "$DST"
log_success "Directory symlinking completed!"
