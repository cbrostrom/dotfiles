#!/bin/zsh
# Recursively symlink all files and subdirectories from source to target using relative paths
# Usage: ./symlink-dir.sh <source_dir> <target_dir>
set -e

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <source_dir> <target_dir>"
    exit 1
fi

SRC=$(realpath "$1")
DST=$(realpath "$2")

if [[ ! -d "$SRC" ]]; then
    echo "Source directory does not exist: $SRC"
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
            echo "Skipping existing: $dst_item"
        else
            rel_src=$(realpath --relative-to="$(dirname "$dst_item")" "$src_item" 2>/dev/null || python3 -c "import os.path; print(os.path.relpath('$src_item', os.path.dirname('$dst_item')))" 2>/dev/null)
            ln -s "$rel_src" "$dst_item"
            echo "Linked: $dst_item -> $rel_src"
        fi
    fi
}

symlink_item "$SRC" "$DST"
