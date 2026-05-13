#!/usr/bin/env bash
# List-file overlay helper.
#
# Given a base list file path (e.g. .claude/plugins.list), emit a merged stream
# of non-comment, non-blank lines from the base + matching overlays:
#
#   <base>                       (always loaded if present)
#   <base>.{platform}.{ext}      (e.g. plugins.darwin.list, plugins.linux.list)
#   <base>.{profile}.{ext}       (e.g. plugins.server-headless.list)
#   <base>.host-{slug}.{ext}     (e.g. plugins.host-linuxbro.list)
#
# Where {ext} = original extension of <base>. Overlay files are constructed by
# inserting the layer tag *before* the final extension:
#   plugins.list           -> plugins.<tag>.list
#   skills.list            -> skills.<tag>.list
#   mcp-servers.list       -> mcp-servers.<tag>.list
#
# Disable token: a line of the form `!<key>` removes any prior or later entry
# whose "key" matches. Key extraction:
#   plugin@market=source  -> "plugin@market"   (everything before first '=')
#   name|cmd|args         -> "name"            (everything before first '|')
#   bare source string    -> the whole line
#
# Usage:
#   . "$DOTFILES_DIR/modules/_lib/lists.sh"
#   while IFS= read -r line; do ...; done < <(lists_merge "$base_path")

if [[ "${_DOTFILES_LISTS_LOADED:-}" == "1" ]]; then
    return 0 2>/dev/null || true
fi
_DOTFILES_LISTS_LOADED=1

. "$DOTFILES_DIR/modules/_lib/platform.sh"

# Extract the canonical key from a list entry. See header for rules.
_lists_key() {
    local line="$1"
    line="${line%%#*}"
    # Strip leading/trailing whitespace.
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    # Cut at first '=' or '|'.
    line="${line%%=*}"
    line="${line%%|*}"
    # Drop internal whitespace.
    line="${line// /}"
    echo "$line"
}

# Build the list of overlay paths to try, in load order.
_lists_paths() {
    local base="$1"
    local dir="${base%/*}"
    local file="${base##*/}"
    local stem ext
    if [[ "$file" == *.* ]]; then
        ext="${file##*.}"
        stem="${file%.*}"
    else
        ext=""
        stem="$file"
    fi

    local platform profile host
    platform="$(platform_tag)"
    profile="$(profile_tag)"
    host="$(host_slug)"

    local tag path
    echo "$base"
    for tag in "$platform" "$profile" "host-$host"; do
        if [[ -n "$ext" ]]; then
            path="$dir/$stem.$tag.$ext"
        else
            path="$dir/$stem.$tag"
        fi
        echo "$path"
    done
}

# Merge overlays for the given base list path and emit deduped entries on stdout.
# Lines starting with '!' in any layer cause matching entries to be dropped.
lists_merge() {
    local base="$1"
    local -a paths=()
    local p
    while IFS= read -r p; do paths+=("$p"); done < <(_lists_paths "$base")

    local -A disabled=()
    local -A seen=()
    local -a entries=()

    # First pass: collect disables.
    local f line key
    for f in "${paths[@]}"; do
        [[ -f "$f" ]] || continue
        while IFS= read -r line || [[ -n "$line" ]]; do
            line="${line%%#*}"
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [[ -z "$line" ]] && continue
            if [[ "$line" == "!"* ]]; then
                key="$(_lists_key "${line#!}")"
                [[ -n "$key" ]] && disabled["$key"]=1
            fi
        done < "$f"
    done

    # Second pass: emit kept entries, deduped by key.
    for f in "${paths[@]}"; do
        [[ -f "$f" ]] || continue
        while IFS= read -r line || [[ -n "$line" ]]; do
            line="${line%%#*}"
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [[ -z "$line" ]] && continue
            [[ "$line" == "!"* ]] && continue
            key="$(_lists_key "$line")"
            [[ -z "$key" ]] && continue
            [[ -n "${disabled[$key]:-}" ]] && continue
            [[ -n "${seen[$key]:-}" ]] && continue
            seen["$key"]=1
            entries+=("$line")
        done < "$f"
    done

    local e
    for e in "${entries[@]}"; do
        printf '%s\n' "$e"
    done
}

# Echo the resolved overlay paths that exist (for logging/debug).
lists_active_paths() {
    local base="$1"
    local p
    while IFS= read -r p; do
        [[ -f "$p" ]] && echo "$p"
    done < <(_lists_paths "$base")
    return 0
}
