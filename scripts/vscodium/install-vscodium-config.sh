#!/usr/bin/env bash
# Install VSCodium config from dotfiles → VSCodium User directory.
# Uses copy (not symlinks) — Windows cannot follow WSL symlinks.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$DOTFILES_DIR/.config/vscodium"

# Color helpers (only when running in a terminal)
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
    GREEN=''; YELLOW=''; RED=''; NC=''
fi
ok()   { printf "${GREEN}[ ok ]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[warn]${NC} %s\n" "$*"; }
err()  { printf "${RED}[err ]${NC} %s\n" "$*" >&2; }

# Detect VSCodium User directory
_vscodium_user_dir() {
    local uname
    uname="$(uname -s)"
    if grep -qi microsoft /proc/version 2>/dev/null; then
        local win_user="${USERNAME:-$(whoami)}"
        echo "/mnt/c/Users/$win_user/AppData/Roaming/VSCodium/User"
    elif [[ "$uname" == "Darwin" ]]; then
        echo "$HOME/Library/Application Support/VSCodium/User"
    else
        echo "$HOME/.config/VSCodium/User"
    fi
}

# Detect codium binary (WSL: prefer Windows exe in PATH)
_codium_bin() {
    if command -v codium >/dev/null 2>&1; then
        echo "codium"
    elif command -v codium.cmd >/dev/null 2>&1; then
        echo "codium.cmd"
    else
        echo ""
    fi
}

# Ensure vscode.git + vscode.git-base are not in the disabled list (settings-optimization sites disable them).
_ensure_git_enabled() {
    local db
    if grep -qi microsoft /proc/version 2>/dev/null; then
        db="/mnt/c/Users/${USERNAME:-$(whoami)}/AppData/Roaming/VSCodium/User/globalStorage/state.vscdb"
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        db="$HOME/Library/Application Support/VSCodium/User/globalStorage/state.vscdb"
    else
        db="$HOME/.config/VSCodium/User/globalStorage/state.vscdb"
    fi
    [[ -f "$db" ]] || return 0
    command -v python3 >/dev/null 2>&1 || return 0
    python3 - "$db" << 'PYEOF'
import sqlite3, json, sys
db = sys.argv[1]
conn = sqlite3.connect(db)
row = conn.execute("SELECT value FROM ItemTable WHERE key='extensionsIdentifiers/disabled'").fetchone()
if not row:
    conn.close()
    sys.exit(0)
disabled = json.loads(row[0])
blocked = {'vscode.git', 'vscode.git-base'}
cleaned = [e for e in disabled if e.get('id') not in blocked]
removed = [e['id'] for e in disabled if e.get('id') in blocked]
if removed:
    conn.execute("UPDATE ItemTable SET value=? WHERE key='extensionsIdentifiers/disabled'", (json.dumps(cleaned),))
    conn.commit()
    print(f"Re-enabled: {', '.join(removed)}")
conn.close()
PYEOF
    ok "Verified vscode.git not in disabled list"
}

# Patch vscodium-server product.json + git extension on WSL so vscode.git activates remotely.
# VSCodium ships with empty extensionKindMap; without it jeanp413.open-remote-wsl never routes
# vscode.git to the server side. Re-run when vscodium-server updates (new commit hash).
_patch_wsl_server_git() {
    command -v python3 >/dev/null 2>&1 || return 0
    [[ -d "$HOME/.vscodium-server/bin" ]] || return 0

    for commit_dir in "$HOME/.vscodium-server/bin"/*/; do
        [[ -d "$commit_dir" ]] || continue

        local product="$commit_dir/product.json"
        local git_pkg="$commit_dir/extensions/git/package.json"

        if [[ -f "$product" ]]; then
            python3 - "$product" << 'PYEOF'
import json, sys
f = sys.argv[1]
d = json.load(open(f))
km = d.setdefault('extensionKindMap', {})
km['vscode.git'] = ['workspace']
km['vscode.git-base'] = ['workspace']
json.dump(d, open(f, 'w'), indent='\t')
PYEOF
            ok "Patched extensionKindMap in $(basename "$commit_dir")/product.json"
        fi

        if [[ -f "$git_pkg" ]]; then
            python3 - "$git_pkg" << 'PYEOF'
import json, sys
f = sys.argv[1]
d = json.load(open(f))
d['extensionKind'] = ['workspace']
json.dump(d, open(f, 'w'), indent='\t')
PYEOF
            ok "Patched extensionKind in git extension package.json"
        fi
    done
}

# Inject platform-specific git.path into a settings JSON file
_inject_git_path() {
    local file="$1"
    command -v jq >/dev/null 2>&1 || return 0

    local git_path=""
    if grep -qi microsoft /proc/version 2>/dev/null; then
        git_path='C:\Program Files\Git\cmd\git.exe'
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        if [[ -x "/opt/homebrew/bin/git" ]]; then
            git_path="/opt/homebrew/bin/git"
        elif [[ -x "/usr/local/bin/git" ]]; then
            git_path="/usr/local/bin/git"
        else
            git_path="/usr/bin/git"
        fi
    else
        git_path="/usr/bin/git"
    fi

    local tmp
    tmp="$(mktemp)"
    jq --arg p "$git_path" '."git.path" = $p' "$file" > "$tmp" && mv "$tmp" "$file"
    ok "Injected git.path: $git_path"
}

# Merge base → local (jq: base fills missing keys, local wins on conflict)
_merge_settings() {
    local base="$SRC/settings.base.json"
    local local_file="$SRC/settings.local.json"
    local example="$SRC/settings.local.example.json"

    if [[ ! -f "$local_file" ]]; then
        if [[ -f "$example" ]]; then
            cp "$example" "$local_file"
            warn "Created settings.local.json from example — review before committing"
        else
            cp "$base" "$local_file"
        fi
    fi

    if ! command -v jq >/dev/null 2>&1; then
        warn "jq not found — copying base settings without local merge (install jq for full support)"
        cp "$base" "$local_file"
        return
    fi

    # Strip JSONC comments before merging (VSCodium accepts comments, jq does not)
    local tmp_base tmp_local merged
    tmp_base="$(mktemp)"
    tmp_local="$(mktemp)"
    merged="$(mktemp)"
    trap "rm -f '$tmp_base' '$tmp_local' '$merged'" RETURN

    sed 's|//.*||g' "$base"       | jq '.' > "$tmp_base"
    sed 's|//.*||g' "$local_file" | jq '.' > "$tmp_local"

    # Merge: base provides defaults, local wins on conflicts
    jq -s '.[0] * .[1]' "$tmp_base" "$tmp_local" > "$merged"
    cp "$merged" "$local_file"
    ok "Merged settings.base.json → settings.local.json"
}

install_config() {
    local dest
    dest="$(_vscodium_user_dir)"

    if [[ ! -d "$dest" ]]; then
        warn "VSCodium User dir not found: $dest (is VSCodium installed?)"
        return 1
    fi

    _merge_settings

    local drifted=()
    for f in keybindings.json tasks.json; do
        if [[ -f "$dest/$f" && -f "$SRC/$f" ]]; then
            if ! diff -q "$SRC/$f" "$dest/$f" >/dev/null 2>&1; then
                drifted+=("$f")
            fi
        fi
    done
    if [[ ${#drifted[@]} -gt 0 ]]; then
        warn "Windows has local edits in: ${drifted[*]} — review before overwriting"
        for f in "${drifted[@]}"; do
            diff "$SRC/$f" "$dest/$f" 2>/dev/null || true
        done
        read -rp "Overwrite? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] || { warn "Skipping overwrite."; return 0; }
    fi

    _ensure_git_enabled

    cp "$SRC/settings.local.json" "$dest/settings.json"
    _inject_git_path "$dest/settings.json"
    ok "Copied settings.json → $dest"

    # On WSL: patch server binary + set remote git path
    if grep -qi microsoft /proc/version 2>/dev/null; then
        local wsl_server_user="$HOME/.vscodium-server/data/User"
        if [[ -d "$HOME/.vscodium-server" ]]; then
            mkdir -p "$wsl_server_user"
            printf '{\n  "git.path": "/usr/bin/git"\n}\n' > "$wsl_server_user/settings.json"
            ok "Set git.path=/usr/bin/git in WSL server settings"
            _patch_wsl_server_git
        fi
    fi

    for f in keybindings.json tasks.json; do
        [[ -f "$SRC/$f" ]] && cp "$SRC/$f" "$dest/$f" && ok "Copied $f → $dest"
    done
}

install_extensions() {
    local ext_file="$SRC/extensions.txt"
    [[ -f "$ext_file" ]] || { warn "No extensions.txt found at $SRC"; return 0; }

    local codium
    codium="$(_codium_bin)"
    if [[ -z "$codium" ]]; then
        warn "codium binary not found in PATH — skipping extension install"
        warn "Add VSCodium to PATH or install extensions manually"
        return 0
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#|^[[:space:]]*$ ]] && continue
        ext_id="${line%% *}"
        if "$codium" --list-extensions 2>/dev/null | grep -qi "^${ext_id}$"; then
            ok "already installed: $ext_id"
        else
            if "$codium" --install-extension "$ext_id" 2>/dev/null; then
                ok "installed: $ext_id"
            else
                warn "failed to install: $ext_id (may not be on Open VSX)"
            fi
        fi
    done < "$ext_file"
}

main() {
    local mode="${1:-config}"
    case "$mode" in
        --install-extensions|-e) install_extensions ;;
        --config|-c|config)      install_config ;;
        --all|-a)                install_config; install_extensions ;;
        *)
            echo "Usage: $(basename "$0") [--config|--install-extensions|--all]"
            exit 1
            ;;
    esac
}

main "$@"
