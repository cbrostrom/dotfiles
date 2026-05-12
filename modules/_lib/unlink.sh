#!/usr/bin/env bash
# Safe symlink reversal for uninstall.sh hooks.
#
# Removes ONLY symlinks whose `readlink -f` target resolves under $DOTFILES_DIR.
# Anything else is left strictly alone — third-party files, user edits, and
# unrelated symlinks are never touched.
#
# Restore behavior: if a sibling `<path>.backup.*` file exists next to the
# removed symlink, it is renamed back into place (newest backup wins). Pass
# UNLINK_KEEP_BACKUPS=1 to skip restoration.
#
# Dry-run: set UNLINK_DRY_RUN=1 to print what would happen without changes.
#
# Public API:
#   unlink_roots <dir1> [<dir2> ...]
#       Recursively walk each dir (depth-limited to 6 to avoid runaway scans)
#       and remove dotfiles-owned symlinks. Skips dirs that don't exist.
#
#   unlink_paths <path1> [<path2> ...]
#       Operate on explicit paths only. Each path is removed if (and only if)
#       it is a symlink resolving into $DOTFILES_DIR.

if [[ "${_DOTFILES_UNLINK_LOADED:-}" == "1" ]]; then
    return 0 2>/dev/null || true
fi
_DOTFILES_UNLINK_LOADED=1

. "$DOTFILES_DIR/modules/_lib/log.sh"

_unlink_resolves_into_dotfiles() {
    local link="$1"
    [[ -L "$link" ]] || return 1
    local target
    target="$(readlink -f -- "$link" 2>/dev/null || true)"
    [[ -z "$target" ]] && return 1
    [[ "$target" == "$DOTFILES_DIR"/* || "$target" == "$DOTFILES_DIR" ]]
}

_unlink_restore_backup() {
    local link="$1"
    [[ "${UNLINK_KEEP_BACKUPS:-0}" == "1" ]] && return 0
    local backup
    # Newest matching backup wins. -d keeps directory entries as-is so a
    # backed-up directory doesn't get expanded into its file contents.
    backup="$(ls -dt -- "$link".backup.* 2>/dev/null | head -1 || true)"
    [[ -z "$backup" ]] && return 0
    [[ -e "$backup" || -L "$backup" ]] || return 0
    if [[ "${UNLINK_DRY_RUN:-0}" == "1" ]]; then
        echo "  would restore backup: $backup -> $link"
    else
        mv -- "$backup" "$link" 2>/dev/null && \
            ok "  restored backup: $(basename "$backup") -> $link"
    fi
}

_unlink_one() {
    local link="$1"
    if ! _unlink_resolves_into_dotfiles "$link"; then
        return 1
    fi
    if [[ "${UNLINK_DRY_RUN:-0}" == "1" ]]; then
        echo "  would remove: $link -> $(readlink "$link")"
    else
        rm -- "$link" && ok "  removed: $link"
    fi
    _unlink_restore_backup "$link"
    return 0
}

unlink_paths() {
    local removed=0
    local p
    for p in "$@"; do
        [[ -L "$p" ]] || continue
        _unlink_one "$p" && ((removed++)) || true
    done
    return 0
}

unlink_roots() {
    local removed=0
    local root
    for root in "$@"; do
        [[ -d "$root" || -L "$root" ]] || continue
        # Find symlinks up to a sane depth (6). Prune $DOTFILES_DIR so we
        # never descend into the source repo when walking $HOME.
        while IFS= read -r -d '' link; do
            _unlink_one "$link" && ((removed++)) || true
        done < <(find -P "$root" -maxdepth 6 \
                    \( -path "$DOTFILES_DIR" -prune \) -o \
                    \( -type l -print0 \) 2>/dev/null)
    done
    return 0
}
