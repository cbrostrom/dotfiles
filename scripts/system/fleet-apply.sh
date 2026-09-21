#!/usr/bin/env bash
# Run one guarded dotfiles update on a remote fleet host.
# The controller streams this file over SSH; it does not need to exist remotely.

set -euo pipefail

host_name="${1:-}"
profile="${2:-}"
repo="${DOTFILES_DIR:-$HOME/dotfiles}"
stage="preflight"
old_revision="unknown"
new_revision="unknown"
finished=false

result() {
    local status="$1"
    printf 'FLEET_RESULT|%s|%s|%s|%s|%s|%s\n' \
        "$host_name" "$status" "$stage" "$old_revision" "$new_revision" "$profile"
}

on_exit() {
    local exit_code=$?
    if [[ "$finished" != true ]]; then
        result "failed:${exit_code}"
    fi
}
trap on_exit EXIT

[[ "$host_name" =~ ^[a-zA-Z0-9._-]+$ ]] || {
    printf 'error: invalid fleet host name: %s\n' "$host_name" >&2
    exit 2
}
[[ "$profile" =~ ^[a-zA-Z0-9._-]+$ ]] || {
    printf 'error: invalid dotfiles profile: %s\n' "$profile" >&2
    exit 2
}
command -v git >/dev/null 2>&1 || {
    printf 'error: git is required\n' >&2
    exit 1
}
command -v flock >/dev/null 2>&1 || {
    printf 'error: flock is required\n' >&2
    exit 1
}
[[ -d "$repo/.git" ]] || {
    printf 'error: dotfiles repository not found: %s\n' "$repo" >&2
    exit 1
}
[[ -x "$repo/install.sh" && -x "$repo/stow.sh" && -x "$repo/scripts/doctor.sh" ]] || {
    printf 'error: dotfiles commands are missing or not executable in %s\n' "$repo" >&2
    exit 1
}
[[ -f "$repo/profiles/$profile.stow" ]] || {
    printf 'error: unknown profile %s in %s\n' "$profile" "$repo" >&2
    exit 2
}

stage="lock"
lock_dir="${XDG_RUNTIME_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles}"
mkdir -p "$lock_dir"
exec 9>"$lock_dir/fleet-update.lock"
flock -n 9 || {
    printf 'error: another dotfiles fleet update is already running\n' >&2
    exit 75
}

stage="repository"
if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
    printf 'error: refusing to update a dirty repository: %s\n' "$repo" >&2
    git -C "$repo" status --short >&2
    exit 3
fi
old_revision="$(git -C "$repo" rev-parse --short HEAD)"
branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD)" || {
    printf 'error: refusing to update a detached HEAD in %s\n' "$repo" >&2
    exit 3
}
upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" || {
    printf 'error: branch %s has no upstream\n' "$branch" >&2
    exit 3
}

stage="git-fetch"
printf '[fleet] %s: fetching %s\n' "$host_name" "$upstream"
git -C "$repo" fetch --prune

stage="git-update"
read -r local_commits remote_commits < <(
    git -C "$repo" rev-list --left-right --count "HEAD...$upstream"
)
if ((local_commits > 0)); then
    printf 'error: branch %s has %d commit(s) not present in %s\n' \
        "$branch" "$local_commits" "$upstream" >&2
    exit 3
fi
printf '[fleet] %s: fast-forwarding %s by %d commit(s)\n' \
    "$host_name" "$branch" "$remote_commits"
git -C "$repo" merge --ff-only "$upstream"
new_revision="$(git -C "$repo" rev-parse --short HEAD)"

stage="stow-plan"
printf '[fleet] %s: validating Stow profile %s\n' "$host_name" "$profile"
"$repo/stow.sh" plan "$profile"

stage="install"
printf '[fleet] %s: applying profile %s\n' "$host_name" "$profile"
"$repo/install.sh" "$profile"

stage="host-config"
host_setup="$repo/setup/hosts/$host_name.sh"
if [[ -f "$host_setup" ]]; then
    printf '[fleet] %s: applying tracked host configuration\n' "$host_name"
    DOTFILES_FLEET_HOST="$host_name" DOTFILES_PROFILE="$profile" bash "$host_setup"
else
    printf '[fleet] %s: no tracked host configuration hook\n' "$host_name"
fi

stage="doctor"
printf '[fleet] %s: running doctor\n' "$host_name"
"$repo/scripts/doctor.sh" "$profile"

stage="repository-postcheck"
if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
    printf 'error: update left tracked or untracked changes in %s\n' "$repo" >&2
    git -C "$repo" status --short >&2
    exit 4
fi

stage="complete"
finished=true
result "ok"
