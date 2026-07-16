#!/usr/bin/env bash
# opencode-web — manage the opencode web UI systemd service
set -euo pipefail

SERVICE="opencode-web.service"
ENV_FILE="$HOME/.config/opencode/web.env"

_cmd="${1:-help}"
shift || true

case "$_cmd" in
    start)
        systemctl --user start "$SERVICE" && echo "opencode-web started" || echo "failed to start" >&2
        ;;
    stop)
        systemctl --user stop "$SERVICE" && echo "opencode-web stopped" || echo "failed to stop" >&2
        ;;
    restart)
        systemctl --user restart "$SERVICE" && echo "opencode-web restarted" || echo "failed to restart" >&2
        ;;
    status)
        systemctl --user status "$SERVICE" --no-pager || true
        echo ""
        if systemctl --user is-active "$SERVICE" >/dev/null 2>&1; then
            echo "  Local:  http://localhost:4096"
            _pw=$(grep -E '^OPENCODE_SERVER_PASSWORD=' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2 || true)
            if [[ -n "$_pw" && "$_pw" != "your-secret-here" ]]; then
                echo "  Auth:   password (set via opencode-web password)"
            else
                echo "  Auth:   none (password commented out — use Traefik/TinyAuth)"
            fi
            if command -v traefik >/dev/null 2>&1 || docker ps 2>/dev/null | grep -q traefik; then
                echo "  Note:   Traefik detected — access via your reverse proxy hostname"
            fi
        fi
        ;;
    logs|log)
        journalctl --user -u "$SERVICE" --no-pager -n 50 "$@"
        ;;
    enable)
        systemctl --user enable "$SERVICE" && echo "opencode-web enabled (starts on boot)"
        ;;
    disable)
        systemctl --user disable "$SERVICE" && echo "opencode-web disabled"
        ;;
    password|passwd)
        [[ $# -gt 0 ]] || { echo "usage: opencode-web password <new-password>" >&2; exit 1; }
        mkdir -p "$(dirname "$ENV_FILE")"
        if [[ -f "$ENV_FILE" ]]; then
            # If password line is commented out, uncomment it first
            if grep -qE '^# OPENCODE_SERVER_PASSWORD=' "$ENV_FILE"; then
                sed -i.bak "s/^# OPENCODE_SERVER_PASSWORD=.*/OPENCODE_SERVER_PASSWORD=$1/" "$ENV_FILE"
            elif grep -qE '^OPENCODE_SERVER_PASSWORD=' "$ENV_FILE"; then
                sed -i.bak "s/^OPENCODE_SERVER_PASSWORD=.*/OPENCODE_SERVER_PASSWORD=$1/" "$ENV_FILE"
            else
                echo "OPENCODE_SERVER_PASSWORD=$1" >> "$ENV_FILE"
            fi
            rm -f "${ENV_FILE}.bak"
        else
            echo "OPENCODE_SERVER_USERNAME=cb" > "$ENV_FILE"
            echo "OPENCODE_SERVER_PASSWORD=$1" >> "$ENV_FILE"
        fi
        echo "password updated — restart to apply: opencode-web restart"
        ;;
    help|--help|-h|"")
        cat >&2 <<'EOF'
opencode-web — manage the opencode web UI service

Usage: opencode-web <command>

Commands:
  start              Start the web UI
  stop               Stop the web UI
  restart            Restart the web UI
  status             Show status + access URLs
  logs               Tail service logs (extra args passed to journalctl)
  enable             Enable on boot
  disable            Disable on boot
  password <pass>    Set server password (uncomments if commented out)

Local access:  http://localhost:4096
Traefik:       access via your reverse proxy hostname
EOF
        exit 0
        ;;
    *)
        echo "opencode-web: unknown command '$_cmd'. Try: opencode-web help" >&2
        exit 1
        ;;
esac
