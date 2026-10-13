# 09-herdr.zsh — Herdr terminal-workspace integration
#
# - Boots (execs) herdr for top-level interactive shells; any shell already
#   inside a herdr pane (HERDR_PANE_ID), an SSH session, or Alacritty is left
#   alone. Escape hatch: HERDR_NO_AUTOSTART=1.
# - Keeps the pane label fresh (git branch + cwd) via precmd/preexec hooks.
# - Wrappers: hpane / hsplit / hnew for pane and workspace plumbing.
# - Saved-machine helpers: herdm / herdmadd / herdmls (see also docs/herdr.md).
# - Pi presets: pigo / piheavy / piarch / pijanitor / pidetective launch pi
#   with the Go model/thinking matrix (mid-session switching stays in pi).

# --- autostart (disabled) ---------------------------------------------------
# No exec of herdr from top-level shells: autostart proved too invasive.
# Launch herdr explicitly (`herd` or the app). Inside herdr panes the module's
# hooks and wrappers below take over automatically.

# --- pane label hooks -------------------------------------------------------
autoload -Uz add-zsh-hook

__herdr_pane_label() {
    emulate -L zsh
    (( $+commands[herdr] )) || return 0
    local label branch
    branch=$(git -C "$PWD" symbolic-ref --short HEAD 2>/dev/null) || branch=""
    if [[ -n "$branch" ]]; then
        label="${branch}:${PWD:t}"
    else
        label="${PWD:t}"
    fi
    herdr pane rename "$HERDR_PANE_ID" "$label" >/dev/null 2>&1 &
}
add-zsh-hook precmd __herdr_pane_label

# --- wrappers ---------------------------------------------------------------
herd() { command herdr "$@"; }

# Split the calling pane: hsplit [direction: right|down]
hsplit() {
    herdr pane split --current --direction "${1:-right}" --cwd "$PWD" --focus
}

# New workspace: hnew [name]
hnew() {
    herdr workspace create "${1:-}" >/dev/null 2>&1 && herdr workspace list
}

# Rename current pane: hren <label>
hren() {
    [[ -n "${HERDR_PANE_ID:-}" ]] || { print "hren: not inside a herdr pane" >&2; return 1; }
    herdr pane rename "$HERDR_PANE_ID" "$1"
}

# --- saved machines ---------------------------------------------------------
herdmls() { herdr machine list --json "$@"; }

# Control a saved machine: herdm <label> [herdr command...]
#   herdm cloudbro agent list
herdm() {
    local label="$1"; shift
    herdr --machine "$label" "$@"
}

# Attach to a downloaded remote machine in the TUI. Alias kept for muscle memory.
herdremote() { herdr --remote "$@"; }

# Parse config/fleet-hosts.conf and print the worker command for a fleet host.
# Machine add is interactive (SSH auth); it prints instead of running.
herdmadd() {
    setopt local_options extended_glob
    local conf="${DOTFILES_DIR:-$HOME/dotfiles}/config/fleet-hosts.conf"
    [[ -r "$conf" ]] || { print "herdmadd: $conf not readable" >&2; return 1; }
    local row target label rest
    for row in ${(f)"$(grep '^[[:space:]]*\"' "$conf")"}; do
        row="${row##[[:space:]]#}"
        rest="${row#\"}"
        rest="${rest%\"*}"
        local -a fields=("${(@s:|:)rest}")
        if [[ "${fields[1]}" == "$1" ]]; then
            target="${fields[4]}@${fields[2]}:${fields[3]}"
            label="${fields[1]}"
            print "herdr machine add '$target' --label '$label'"
            print "then verify:  herdr machine status '$label'"
            return 0
        fi
    done
    print "herdmadd: fleet host '$1' not found in fleet-hosts.conf" >&2
    return 1
}

# --- Pi Go presets (model + thinking; /preset switches mid-session) ---------
pigo()        { pi --model "opencode-go/glm-5.3-flash:low" "$@"; }
piheavy()     { pi --model "opencode-go/kimi-k2.7-code:medium" "$@"; }
piarch()      { pi --model "opencode-go/glm-5.3:high" "$@"; }
pijanitor()   { pi --model "opencode-go/deepseek-v4-flash:minimal" "$@"; }
pidetective() { pi --model "opencode-go/deepseek-v4-pro:medium" "$@"; }
