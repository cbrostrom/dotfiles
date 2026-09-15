#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_DIR="$ROOT/stow"
TARGET="${STOW_TARGET:-$HOME}"

usage() {
    cat <<'EOF'
Usage: ./stow.sh <plan|apply|remove> [profile]

Profiles:
  macos    Zsh, Git, CLI, agents, Cursor, Pi, desktop, Zed, Ghostty
  linux    Zsh, Git, CLI, agents, Pi, Zed, Ghostty
  wsl      Zsh, Git, CLI, agents, Cursor, Pi, Zed
  server   Minimal shell, Git, CLI, and agent policy
  cloudbro Linux development box with Paseo and Pi, without GUI or OpenCode CLI

Set STOW_TARGET to test against an isolated home directory.
EOF
}

[[ $# -ge 1 ]] || {
    usage
    exit 2
}

command="$1"
profile="${2:-}"

if ! command -v stow >/dev/null 2>&1; then
    printf 'error: GNU Stow is required; install it first (Debian: ./scripts/install/debian.sh <profile> — macOS: brew install stow)\n' >&2
    exit 1
fi

if [[ -z "$profile" ]]; then
    case "$(uname -s)" in
        Darwin) profile="macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                profile="wsl"
            else
                profile="linux"
            fi
            ;;
        *)
            printf 'error: cannot infer profile; pass macos, linux, wsl, server, or cloudbro\n' >&2
            exit 2
            ;;
    esac
fi

profile_file="$ROOT/profiles/$profile.stow"
if [[ ! -f "$profile_file" ]]; then
    printf 'error: unknown profile: %s\n' "$profile" >&2
    exit 2
fi

packages=()
while IFS= read -r package; do
    [[ -n "$package" && "$package" != \#* ]] && packages+=("$package")
done <"$profile_file"

mkdir -p "$TARGET"
args=(
    --dir="$STOW_DIR"
    --target="$TARGET"
    --no-folding
    --verbose=1
    --ignore='.*\.zwc$'
    --ignore='(^|/)\.DS_Store$'
)
case "$command" in
    plan) args+=(--simulate --restow) ;;
    apply) args+=(--restow) ;;
    remove) args+=(--delete) ;;
    -h | --help | help)
        usage
        exit 0
        ;;
    *)
        printf 'error: unknown command: %s\n' "$command" >&2
        usage >&2
        exit 2
        ;;
esac

printf '%s %s in %s\n' "$command" "$profile" "$TARGET"
stow "${args[@]}" "${packages[@]}"
