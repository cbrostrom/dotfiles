# =============================================================================
# DOTFILES AUTO-UPDATE NOTIFICATION
# =============================================================================
# Background fetch + tiered notify when origin/master is ahead.
# Never auto-pulls in interactive shells (opt-in via DOTFILES_UPDATE_ON_EXIT).
#
# Opt-out:           export DOTFILES_AUTOCHECK=0
# Opt-in exit-pull:  export DOTFILES_UPDATE_ON_EXIT=1
# Tunables:          DOTFILES_THROTTLE_SECONDS (default 14400 = 4h)
#                    DOTFILES_FETCH_TIMEOUT (default 3)
#                    DOTFILES_STALE_DAYS (default 7)

[[ -o interactive ]] || return
[[ "$DOTFILES_AUTOCHECK" == "0" ]] && return

DOTFILES_REPO="${DOTFILES_DIR:-$HOME/dotfiles}"
[[ -d "$DOTFILES_REPO/.git" ]] || return

DOTFILES_STATE_DIR="$HOME/.cache/dotfiles"
: "${DOTFILES_THROTTLE_SECONDS:=14400}"
: "${DOTFILES_FETCH_TIMEOUT:=3}"
: "${DOTFILES_STALE_DAYS:=7}"

mkdir -p "$DOTFILES_STATE_DIR"

_DF_LAST_ATTEMPT="$DOTFILES_STATE_DIR/last-attempt"
_DF_LAST_FETCH="$DOTFILES_STATE_DIR/last-fetch"
_DF_STATUS="$DOTFILES_STATE_DIR/status"
_DF_NOTIFIED="$DOTFILES_STATE_DIR/notified-sha"
_DF_OWN_PUSHES="$DOTFILES_STATE_DIR/own-pushes"

_df_mtime() {
    local m
    m=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null)
    [[ "$m" == <-> ]] && echo "$m" || echo 0
}
_df_age() {
    local m=$(_df_mtime "$1")
    echo $(( $(date +%s) - m ))
}

_df_format_age() {
    local s=$1
    if   (( s < 3600 ));  then echo "$(( s / 60 ))m"
    elif (( s < 86400 )); then echo "$(( s / 3600 ))h"
    else                       echo "$(( s / 86400 ))d"
    fi
}

_df_should_check() {
    [[ ! -f "$_DF_LAST_ATTEMPT" ]] && return 0
    local age=$(_df_age "$_DF_LAST_ATTEMPT")
    (( ${age:-0} > ${DOTFILES_THROTTLE_SECONDS:-14400} ))
}

_df_with_timeout() {
    if [[ -n "$DOTFILES_TIMEOUT_BIN" ]]; then
        "$DOTFILES_TIMEOUT_BIN" "$DOTFILES_FETCH_TIMEOUT" "$@"
    else
        "$@" &
        local pid=$!
        ( sleep "$DOTFILES_FETCH_TIMEOUT"; kill -0 $pid 2>/dev/null && kill $pid 2>/dev/null ) &!
        wait $pid 2>/dev/null
    fi
}

_df_bg_fetch() {
    (
        cd "$DOTFILES_REPO" 2>/dev/null || exit
        touch "$_DF_LAST_ATTEMPT"
        _df_with_timeout "$DOTFILES_GIT_BIN" fetch --quiet origin 2>/dev/null || exit
        touch "$_DF_LAST_FETCH"

        local head_sha origin_sha behind dirty conflicts=0
        head_sha=$("$DOTFILES_GIT_BIN" rev-parse HEAD 2>/dev/null)
        origin_sha=$("$DOTFILES_GIT_BIN" rev-parse '@{u}' 2>/dev/null)
        behind=$("$DOTFILES_GIT_BIN" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
        dirty=$("$DOTFILES_GIT_BIN" status --porcelain 2>/dev/null | head -1)

        if (( behind > 0 )); then
            "$DOTFILES_GIT_BIN" merge-tree HEAD '@{u}' 2>/dev/null | grep -q '^<<<<<<<' && conflicts=1
        fi

        {
            printf 'behind=%s\n' "$behind"
            printf 'dirty=%q\n'  "$dirty"
            printf 'head_sha=%s\n'   "$head_sha"
            printf 'origin_sha=%s\n' "$origin_sha"
            printf 'conflicts=%s\n'  "$conflicts"
        } > "$_DF_STATUS"
    ) &!
}

_df_notify() {
    [[ ! -f "$_DF_STATUS" ]] && return
    local behind dirty head_sha origin_sha conflicts
    source "$_DF_STATUS" 2>/dev/null

    local current_head
    current_head=$("$DOTFILES_GIT_BIN" -C "$DOTFILES_REPO" rev-parse HEAD 2>/dev/null)
    if [[ "$current_head" == "$origin_sha" ]]; then
        rm -f "$_DF_STATUS" "$_DF_NOTIFIED"
        return
    fi

    [[ -z "$behind" || "$behind" == "0" ]] && return

    [[ -f "$_DF_NOTIFIED" && "$(<"$_DF_NOTIFIED")" == "$origin_sha" ]] && return

    if [[ -f "$_DF_OWN_PUSHES" ]] && grep -qF "$origin_sha" "$_DF_OWN_PUSHES" 2>/dev/null; then
        echo "$origin_sha" > "$_DF_NOTIFIED"
        return
    fi

    if [[ -f "$_DF_LAST_FETCH" ]]; then
        local fetch_age=$(_df_age "$_DF_LAST_FETCH")
        if (( fetch_age > DOTFILES_STALE_DAYS * 86400 )); then
            print -P "%F{magenta}? dotfiles: last successful fetch $(_df_format_age $fetch_age) ago — network issue?%f"
        fi
    fi

    local upstream_ts now commit_age color icon suffix
    upstream_ts=$("$DOTFILES_GIT_BIN" -C "$DOTFILES_REPO" log -1 --format=%ct '@{u}' 2>/dev/null || echo 0)
    now=$(date +%s)
    commit_age=$(( now - upstream_ts ))

    if [[ -n "$dirty" ]]; then
        color=yellow; icon='!'
        suffix=" + dirty tree — commit/stash, then 'dotfiles-update'"
    elif [[ "$conflicts" == "1" ]]; then
        color=yellow; icon='!'
        suffix=" — merge conflicts expected, run 'dotfiles-update' carefully"
    elif (( commit_age > 7 * 86400 )); then
        color=red; icon='!!'
        suffix=" ($(_df_format_age $commit_age) old) — run 'dotfiles-update'"
    elif (( commit_age > 86400 )); then
        color=yellow; icon='*'
        suffix=" ($(_df_format_age $commit_age) old) — consider 'dotfiles-update'"
    else
        color=cyan; icon='v'
        suffix=" — run 'dotfiles-update' to sync"
    fi

    print -P "%F{$color}$icon dotfiles: $behind commit(s) behind$suffix%f"
    echo "$origin_sha" > "$_DF_NOTIFIED"
}

_df_should_check && _df_bg_fetch

autoload -Uz add-zsh-hook
_df_precmd_once() {
    _df_notify
    add-zsh-hook -d precmd _df_precmd_once
}
add-zsh-hook precmd _df_precmd_once

if [[ "$DOTFILES_UPDATE_ON_EXIT" == "1" ]]; then
    _df_zshexit() {
        [[ ! -f "$_DF_STATUS" ]] && return
        local behind dirty conflicts
        source "$_DF_STATUS" 2>/dev/null
        [[ "$behind" == "0" || -z "$behind" ]] && return
        [[ -n "$dirty" || "$conflicts" == "1" ]] && return
        "$DOTFILES_GIT_BIN" -C "$DOTFILES_REPO" pull --ff-only --quiet 2>/dev/null \
            && rm -f "$_DF_STATUS" "$_DF_NOTIFIED"
    }
    add-zsh-hook zshexit _df_zshexit
fi
