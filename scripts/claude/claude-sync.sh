#!/usr/bin/env bash
# Syncs Claude memory files and desktop app config across machines.
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.config/dotfiles}"
CLAUDE_PROJECTS="$HOME/.claude/projects"
MEMORIES_DIR="$DOTFILES/.claude/memories"
DESKTOP_CONFIG="$DOTFILES/.claude/desktop/claude_desktop_config.json"

detect_desktop_path() {
    case "$(uname -s)" in
        Darwin)
            echo "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
            ;;
        Linux)
            local claude_path
            for claude_path in /mnt/c/Users/*/AppData/Roaming/Claude; do
                [ -d "$claude_path" ] && {
                    echo "$claude_path/claude_desktop_config.json"
                    return
                }
            done
            echo ""
            ;;
        *)
            echo ""
            ;;
    esac
}

# Sync src/ into dst/. delete=true mirrors --delete (remove stale files).
_sync_dir() {
    local src="$1" dst="$2" with_delete="${3:-false}"
    mkdir -p "$dst"
    if command -v rsync >/dev/null 2>&1; then
        if [ "$with_delete" = "true" ]; then
            rsync -a --delete "$src/" "$dst/"
        else
            rsync -a "$src/" "$dst/"
        fi
    else
        [ "$with_delete" = "true" ] && find "${dst:?}" -mindepth 1 -delete 2>/dev/null || true
        cp -r "$src/." "$dst/"
    fi
}

usage() {
    echo "Usage: claude-sync <push|pull|status>"
    echo ""
    echo "  push    Copy memory + desktop config from local → dotfiles, commit"
    echo "  pull    Copy memory + desktop config from dotfiles → local"
    echo "  status  Show drift between local and dotfiles"
    exit 1
}

sync_memories_push() {
    local count=0
    for memory_dir in "$CLAUDE_PROJECTS"/*/memory; do
        [ -d "$memory_dir" ] || continue
        local slug
        slug=$(basename "$(dirname "$memory_dir")")
        local dest="$MEMORIES_DIR/$slug"
        mkdir -p "$dest"
        _sync_dir "$memory_dir" "$dest" true
        count=$((count + 1))
    done
    echo "Memory: synced $count project director(ies)"
}

sync_memories_pull() {
    local count=0
    for slug_dir in "$MEMORIES_DIR"/*/; do
        [ -d "$slug_dir" ] || continue
        local slug
        slug=$(basename "$slug_dir")
        local dest="$CLAUDE_PROJECTS/$slug/memory"
        mkdir -p "$dest"
        _sync_dir "$slug_dir" "$dest"
        count=$((count + 1))
    done
    echo "Memory: restored $count project director(ies)"
}

sync_desktop_push() {
    local desktop_path
    desktop_path=$(detect_desktop_path)
    if [ -z "$desktop_path" ] || [ ! -f "$desktop_path" ]; then
        echo "Desktop: no claude_desktop_config.json found (skipping)"
        return
    fi
    cp "$desktop_path" "$DESKTOP_CONFIG"
    echo "Desktop: pushed from $desktop_path"
}

sync_desktop_pull() {
    local desktop_path
    desktop_path=$(detect_desktop_path)
    if [ -z "$desktop_path" ]; then
        echo "Desktop: platform not detected as macOS or WSL (skipping)"
        return
    fi
    if [ ! -f "$DESKTOP_CONFIG" ]; then
        echo "Desktop: no dotfiles config found at $DESKTOP_CONFIG (skipping)"
        return
    fi
    mkdir -p "$(dirname "$desktop_path")"
    cp "$DESKTOP_CONFIG" "$desktop_path"
    echo "Desktop: pulled to $desktop_path"
}

cmd_push() {
    echo "=== claude-sync push ==="
    sync_memories_push
    sync_desktop_push

    cd "$DOTFILES"
    if git diff --quiet -- .claude/memories/ .claude/desktop/ && \
       ! git ls-files --others --exclude-standard .claude/memories/ .claude/desktop/ | grep -q .; then
        echo "Nothing changed — no commit needed"
        return
    fi
    git add .claude/memories/ .claude/desktop/
    git commit -m "chore(claude): sync memory + desktop config [$(date +%Y-%m-%d)]"
    echo "Committed"
}

cmd_pull() {
    echo "=== claude-sync pull ==="
    sync_memories_pull
    sync_desktop_pull
}

cmd_status() {
    echo "=== Skills ==="
    if [ -L "$HOME/.claude/skills" ]; then
        echo "  OK: ~/.claude/skills → $(readlink "$HOME/.claude/skills")"
    else
        echo "  WARN: ~/.claude/skills ikke symlinket — kør install-claude-config.sh"
    fi

    echo ""
    echo "=== Memory ==="
    local found=0
    for memory_dir in "$CLAUDE_PROJECTS"/*/memory; do
        [ -d "$memory_dir" ] || continue
        found=1
        local slug
        slug=$(basename "$(dirname "$memory_dir")")
        local dest="$MEMORIES_DIR/$slug"
        if [ ! -d "$dest" ]; then
            echo "  NYT (ikke i dotfiles): $slug"
            continue
        fi
        local diff
        if command -v rsync >/dev/null 2>&1; then
            diff=$(rsync -an --delete "$memory_dir/" "$dest/" 2>/dev/null | grep -v "/$" | head -5 || true)
        else
            diff=$(diff -rq "$memory_dir/" "$dest/" 2>/dev/null | head -5 || true)
        fi
        if [ -n "$diff" ]; then
            echo "  ÆNDRET: $slug"
            echo "$diff" | sed 's/^/    /'
        else
            echo "  OK: $slug"
        fi
    done
    [ "$found" -eq 0 ] && echo "  (ingen project memory dirs fundet)"

    echo ""
    echo "=== Desktop MCP config ==="
    local desktop_path
    desktop_path=$(detect_desktop_path)
    if [ -z "$desktop_path" ]; then
        echo "  Platform: ikke macOS eller WSL"
    elif [ ! -f "$desktop_path" ]; then
        echo "  Ikke installeret: $desktop_path"
    elif [ ! -f "$DESKTOP_CONFIG" ]; then
        echo "  NYT (ikke i dotfiles): $desktop_path"
    else
        local diff
        diff=$(diff "$desktop_path" "$DESKTOP_CONFIG" | head -10 || true)
        if [ -n "$diff" ]; then
            echo "  ÆNDRET: $desktop_path"
            echo "$diff" | sed 's/^/    /'
        else
            echo "  OK: $desktop_path"
        fi
    fi
}

case "${1:-}" in
    push)   cmd_push ;;
    pull)   cmd_pull ;;
    status) cmd_status ;;
    *)      usage ;;
esac
