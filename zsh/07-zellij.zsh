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
# Fallback heuristic: no DISPLAY/WAYLAND → headless
if [[ -z "$_zj_profile" ]]; then
    if [[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" && -z "$WSL_DISTRO_NAME" ]]; then
        _zj_profile="server-headless"
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
    exec zellij attach -c "$_zj_session"
fi

unset _zj_profile _zj_session
