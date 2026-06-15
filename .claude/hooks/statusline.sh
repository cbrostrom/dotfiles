#!/usr/bin/env bash
# Claude Code statusline
# Left:  [icon] host ·  cwd · ⎇ branch ✎
# Right: model · ⚡ effort · ▰▱ ctx% · 🪨 savings · $cost

input=$(cat)

# Parse JSON — single jq call
eval "$(echo "$input" | jq -r '@sh "
  MODEL=\(.model.display_name // "")
  PCT=\((.context_window.used_percentage // 0) | floor)
  EFFORT=\(.effort.level // "")
  SESSION_ID=\(.session_id // "")
"' 2>/dev/null)" 2>/dev/null

# Icons
if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    machine_icon=$'\xef\x84\x88'  # U+F108 nf-fa-desktop
else
    machine_icon=$'\xef\x86\xb3'  # U+F1B3 nf-fa-cubes (server stack)
fi
folder_icon=$'\xef\x81\xbb'       # U+F07B nf-fa-folder
pencil_icon=$'\xef\x81\x80'       # U+F040 nf-fa-pencil (dirty)
branch_icon=$'\xef\xa3\xa6'       # nf branch glyph

# ── SESSION CACHE (git remote — never changes within a session) ───────────────

CACHE_DIR="/tmp/claude-statusline"
mkdir -p "$CACHE_DIR" 2>/dev/null
remote_url=""
if [[ -n "$SESSION_ID" ]]; then
    cache_file="$CACHE_DIR/${SESSION_ID}.remote"
    if [[ -f "$cache_file" ]]; then
        remote_url="$(cat "$cache_file")"
    else
        remote_url="$(git remote get-url origin 2>/dev/null \
            | sed 's/git@github\.com:/https:\/\/github.com\//' \
            | sed 's/\.git$//')"
        printf '%s' "$remote_url" > "$cache_file"
    fi
else
    remote_url="$(git remote get-url origin 2>/dev/null \
        | sed 's/git@github\.com:/https:\/\/github.com\//' \
        | sed 's/\.git$//')"
fi

# ── WIDTH CALC (Python, cached per left+right content hash) ───────────────────

printable_widths() {
    local left="$1" right="$2"
    local hash key cache_file result
    hash="$(printf '%s\n%s' "$left" "$right" | md5sum | cut -c1-8)"
    cache_file="$CACHE_DIR/width_${hash}"
    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
    else
        result="$(python3 - "$left" "$right" <<'PY'
import sys, re, unicodedata
def w(s):
    s = re.sub(r'\x1b\[[0-9;]*[mGKHF]', '', s)
    s = re.sub(r'\x1b\]8;;[^\x07]*\x07[^\x1b]*\x1b\]8;;\x07', '', s)
    total = 0
    for c in s:
        cp = ord(c)
        eaw = unicodedata.east_asian_width(c)
        # emoji blocks render as double-width in most terminals
        if (0x1F000 <= cp <= 0x1FFFF) or (0x2600 <= cp <= 0x27BF) or (0x1FA00 <= cp <= 0x1FAFF):
            total += 2
        elif eaw in ('W', 'F'):
            total += 2
        else:
            total += 1
    return total
print(w(sys.argv[1]), w(sys.argv[2]))
PY
)"
        printf '%s' "$result" > "$cache_file"
        printf '%s' "$result"
    fi
}

# ── LEFT: host ·  cwd · ⎇ branch ─────────────────────────────────────────────

left="$(printf '\033[38;2;79;195;247m%s %s\033[0m' "$machine_icon" "$(hostname -s)")"

cwd_val="${PWD:-}"
if [[ -n "$cwd_val" ]]; then
    cwd_val="${cwd_val/#$HOME/\~}"
    cwd_val="$(printf '%s' "$cwd_val" | awk -F/ 'NF>2{print "…/" $(NF-1) "/" $NF} NF==2{print $1 "/" $2} NF<=1{print $0}')"
    left+="$(printf ' \033[38;5;240m·\033[0m \033[38;2;231;111;81m%s %s\033[0m' "$folder_icon" "$cwd_val")"
fi

if command -v git >/dev/null 2>&1; then
    branch="$(git branch --show-current 2>/dev/null)"
    if [[ -n "$branch" ]]; then
        # Cache branch state (dirty + ahead/behind) — 5s TTL
        git_cache="$CACHE_DIR/${SESSION_ID:-nogit}.git"
        git_stale=true
        if [[ -f "$git_cache" ]]; then
            age=$(( $(date +%s) - $(stat -c %Y "$git_cache" 2>/dev/null || echo 0) ))
            [[ $age -le 5 ]] && git_stale=false
        fi
        if $git_stale; then
            is_dirty=0
            git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null || is_dirty=1
            # shellcheck disable=SC1083
            read -r ahead behind < <(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null || echo "0 0")
            printf '%s|%s|%s|%s' "$branch" "$is_dirty" "${ahead:-0}" "${behind:-0}" > "$git_cache"
        fi
        IFS='|' read -r _b is_dirty ahead behind < "$git_cache"

        dirty=""
        [[ "$is_dirty" == "1" ]] \
            && dirty="$(printf ' \033[38;5;167m%s\033[0m' "$pencil_icon")"

        # Ahead/behind indicators
        sync=""
        [[ "${ahead:-0}" -gt 0 ]] && sync+="$(printf ' \033[38;5;75m↑%s\033[0m' "$ahead")"
        [[ "${behind:-0}" -gt 0 ]] && sync+="$(printf ' \033[38;5;204m↓%s\033[0m' "$behind")"

        # Branch color: green = clean, orange = dirty
        if [[ "$is_dirty" == "1" ]]; then
            branch_clr='\033[38;2;244;162;97m'  # orange
        else
            branch_clr='\033[38;2;130;190;100m'  # green
        fi

        branch_text="$branch"

        left+="$(printf " \033[38;5;240m·\033[0m ${branch_clr}%s %s\033[0m" \
            "$branch_icon" "$branch_text")${dirty}${sync}"
    fi
fi

# caveman rock — left side, after git
CAVEMAN_FLAG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.caveman-active"
CAVEMAN_SAVINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.caveman-statusline-suffix"
if [[ -f "$CAVEMAN_FLAG" && ! -L "$CAVEMAN_FLAG" ]]; then
    _mode="$(head -c 64 "$CAVEMAN_FLAG" 2>/dev/null | tr -d '\n\r[:space:]' | tr '[:upper:]' '[:lower:]')"
    case "$_mode" in
        off) ;;
        lite|full|ultra|wenyan*|commit|review|compress|"")
            _savings=""
            if [[ -f "$CAVEMAN_SAVINGS" && ! -L "$CAVEMAN_SAVINGS" ]]; then
                _savings="$(head -c 64 "$CAVEMAN_SAVINGS" 2>/dev/null | tr -d '\000-\037')"
            fi
            left+=" $(printf '\033[38;5;172m🪨\033[0m')"
            [[ -n "$_savings" ]] && left+=" $(printf '\033[38;5;172m%s\033[0m' "$_savings")"
            ;;
    esac
fi

# ── RIGHT: model · effort · ctx · cost ────────────────────────────────────────

right=""

[[ -n "$MODEL" ]] && right+="$(printf '\033[38;5;39m%s\033[0m' "$MODEL")"

if [[ -n "$EFFORT" ]]; then
    [[ -n "$right" ]] && right+="$(printf ' \033[38;5;240m·\033[0m')"
    right+=" $(printf '\033[38;5;214m⚡ %s\033[0m' "$EFFORT")"
fi

if [[ "$PCT" =~ ^[0-9]+$ && "$PCT" -gt 0 ]]; then
    bar_width=5
    filled=$(( (PCT * bar_width + 50) / 100 ))
    empty=$(( bar_width - filled ))
    bar=""
    for ((i=0; i<filled; i++)); do bar+="▰"; done
    for ((i=0; i<empty; i++)); do bar+="▱"; done
    if   [[ $PCT -ge 90 ]]; then bar_clr='\033[38;5;167m'
    elif [[ $PCT -ge 70 ]]; then bar_clr='\033[38;5;214m'
    else                          bar_clr='\033[38;5;71m'; fi
    [[ -n "$right" ]] && right+="$(printf ' \033[38;5;240m·\033[0m')"
    right+=" $(printf "${bar_clr}%s %d%%\033[0m" "$bar" "$PCT")"
fi


# ── RIGHT-ALIGN ───────────────────────────────────────────────────────────────

term_width="${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}"
read -r left_w right_w < <(printable_widths "$left" "$right")
pad=$(( term_width - ${left_w:-0} - ${right_w:-0} - 6 ))
[[ $pad -lt 2 ]] && pad=2
printf -v _padding "%${pad}s" ""

printf '%s%s%s' "$left" "$_padding" "$right"
