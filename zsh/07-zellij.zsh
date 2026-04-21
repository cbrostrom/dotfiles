# =============================================================================
# ZELLIJ AUTO-ATTACH (loaded LAST so all earlier modules register first)
# =============================================================================
# Auto-attach (or create) a Zellij session named after the current host.
# Per-host session naming prevents clashes across mac / linuxbro / superbro /
# monsterbro-WSL when reaching machines via Tailscale-SSH.
#
# Skips:
#   - nested Zellij
#   - non-interactive shells
#   - SSH sessions (local zellij stays on the local machine)
#   - editor-integrated terminals (VS Code / Cursor)
#   - server-headless profile (e.g. superbro VPS — opt-in via `zj` instead)
# =============================================================================

# Determine profile (set in ~/.local-config or auto-detect)
_zj_profile="${PROFILE:-}"
if [[ -z "$_zj_profile" && -f "$HOME/.local-config" ]]; then
    _zj_profile="$(grep -E '^PROFILE=' "$HOME/.local-config" 2>/dev/null | cut -d= -f2 | tr -d '"')"
fi
# Fallback heuristic: only Linux without DISPLAY/Wayland counts as headless.
# macOS GUI never sets DISPLAY (X11 only) — must not be classified as headless.
if [[ -z "$_zj_profile" ]]; then
    if [[ "$OSTYPE" == darwin* ]]; then
        _zj_profile="desktop-full"
    elif [[ -n "$WSL_DISTRO_NAME" ]]; then
        _zj_profile="wsl"
    elif [[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
        _zj_profile="server-headless"
    else
        _zj_profile="desktop-full"
    fi
fi

if command -v zellij >/dev/null 2>&1 \
   && [[ -z "$ZELLIJ" ]] \
   && [[ $- == *i* ]] \
   && [[ -z "$SSH_CONNECTION" ]] \
   && [[ -z "$SSH_CLIENT" ]] \
   && [[ -z "$SSH_TTY" ]] \
   && [[ -z "$VSCODE_INJECTION" ]] \
   && [[ -z "$CURSOR_TRACE_ID" ]] \
   && [[ "$TERM_PROGRAM" != "vscode" ]] \
   && [[ "$_zj_profile" != "server-headless" ]]; then
    export ZELLIJ_AUTO_ATTACH=true
    export ZELLIJ_AUTO_EXIT=true
    _zj_session="$(hostname -s 2>/dev/null || echo main)"

    # ---------------------------------------------------------------------
    # Per-host default layout
    # ---------------------------------------------------------------------
    # Override per machine via ~/.zshrc.local:  export ZJ_DEFAULT_LAYOUT=dev
    # Falls back to host-name mapping below, then to 'default'.
    case "$_zj_session" in
        AKQABro|mac|Macbook*|*macbook*) _zj_layout="dev" ;;
        linuxbro|cloudbro)              _zj_layout="ops" ;;
        superbro)                       _zj_layout="vps" ;;
        monsterbro|*WSL*|*wsl*)         _zj_layout="dev" ;;
        *)                              _zj_layout="default" ;;
    esac
    _zj_layout="${ZJ_DEFAULT_LAYOUT:-$_zj_layout}"

    exec zellij --layout "$_zj_layout" attach -c "$_zj_session"
fi

unset _zj_profile _zj_session _zj_layout
