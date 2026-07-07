# fnm for login shells (LaunchAgents, pi-web services, cron, etc.)
# Interactive shells also get fnm from 02-plugins.zsh; this covers non-interactive -lc shells.
if command -v fnm &>/dev/null; then
    export FNM_COREPACK_ENABLED=true
    eval "$(fnm env --use-on-cd)"
fi
