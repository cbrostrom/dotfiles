#!/usr/bin/env bash
# fleet-reboot-notify.sh — push a Pushover notification when this box boots.
#
# Expects a readable 0600 config at $HOME/.config/fleet/reboot-notify.conf:
#     PUSH_TOKEN=az...(app token from https://pushover.net)
#     PUSH_USER=uxxx...(user key)
# The token/user pair is delivery credential; it never leaves the host conf
# (Bitwarden item 'Fleet Watch' is the source of truth).
#
# Installs (needs sudo):
#   ~/.local/bin/fleet-reboot-push   the one-shot push command
#   /etc/systemd/system/fleet-reboot-notify.service   oneshot, on the boot
# Works when invoked via plain `bash` or under sudo (resolves invoking user,
# since sudo sets HOME=/root).

set -euo pipefail

# Work under sudo: HOME is /root, but the conf belongs to the invoking user.
_target_user="${SUDO_USER:-${USER}}"
_target_home="$(eval echo "~${_target_user}")"
CONF="${_target_home}/.config/fleet/reboot-notify.conf"
if [[ ! -r "$CONF" ]]; then
    echo "missing config: $CONF (PUSH_TOKEN=..., PUSH_USER=...)" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$CONF"

# 1) Wrapper script: the real push, run in a shell (no systemd arg-parsing).
_wrapper="${_target_home}/.local/bin/fleet-reboot-push"
mkdir -p "$(dirname "$_wrapper")"
cat > "${HOME}/.fleet-reboot-push.tmp" <<EOF
#!/bin/sh
. ${CONF}
/usr/bin/curl -fsS -m 15 --connect-timeout 5 https://api.pushover.net/1/messages.json \\
    -d "token=\$PUSH_TOKEN" -d "user=\$PUSH_USER" -d priority=-1 \\
    -d "title=Fleet Watch" -d "message=\$(hostname -s) rebooted \$(date -u +%Y-%m-%dT%H:%M%Z)"
EOF
sudo install -m 0755 -o "${_target_user}" -g "$(id -gn "${_target_user}")" "${HOME}/.fleet-reboot-push.tmp" "$_wrapper"
rm -f "${HOME}/.fleet-reboot-push.tmp"

# 2) System unit: minus oneshot that runs the wrapper as the owning user.
UNIT="/etc/systemd/system/fleet-reboot-notify.service"
sudo tee "$UNIT" >/dev/null <<UNIT
[Unit]
Description=Fleet watchdog: Pushover "host booted" push
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=${_target_user}
Restart=on-failure
RestartSec=10
ExecStart=${_wrapper}
EnvironmentFile=-${CONF}

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable fleet-reboot-notify.service

echo "installed: $UNIT (fires on next boot)"
