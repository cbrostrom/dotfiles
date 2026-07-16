#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/config.sh"
. "$DOTFILES_DIR/modules/_lib/platform.sh"

log "installing OpenCode config …"

# ── Binary ───────────────────────────────────────────────────────────────────
if command -v opencode >/dev/null 2>&1; then
    ok "opencode already installed: $(opencode --version 2>/dev/null || echo 'unknown')"
else
    log "installing opencode binary"
    curl -fsSL https://opencode.ai/install | bash
    ok "opencode binary installed"
fi

# ── Config directory ─────────────────────────────────────────────────────────
mkdir -p "$HOME/.config/opencode"

# Symlink opencode.json from dotfiles repo
opencode_json="$DOTFILES_DIR/.config/opencode/opencode.json"
if [[ -f "$opencode_json" ]]; then
    if [[ -L "$HOME/.config/opencode/opencode.json" ]]; then
        rm "$HOME/.config/opencode/opencode.json"
    fi
    ln -sf "$opencode_json" "$HOME/.config/opencode/opencode.json"
    ok "linked opencode.json"
else
    warn "opencode.json not found at $opencode_json — skipping"
fi

# Symlink AGENTS.md from dotfiles repo
opencode_agents="$DOTFILES_DIR/.config/opencode/AGENTS.md"
if [[ -f "$opencode_agents" ]]; then
    if [[ -L "$HOME/.config/opencode/AGENTS.md" ]]; then
        rm "$HOME/.config/opencode/AGENTS.md"
    fi
    ln -sf "$opencode_agents" "$HOME/.config/opencode/AGENTS.md"
    ok "linked opencode AGENTS.md"
else
    warn "opencode AGENTS.md not found at $opencode_agents — skipping"
fi

# Symlink skills → ~/.agents/skills (ensures opencode discovers shared skills)
agents_skills="$HOME/.agents/skills"
opencode_skills="$HOME/.config/opencode/skills"
if [[ -d "$agents_skills" ]]; then
    if [[ -L "$opencode_skills" ]]; then
        rm "$opencode_skills"
    fi
    ln -sf "$agents_skills" "$opencode_skills"
    ok "linked opencode skills: $opencode_skills -> $agents_skills"
else
    warn "~/.agents/skills not found — skills symlink skipped"
fi

ok "opencode config complete"

# ── Web UI autostart (auto on server-headless, opt-in elsewhere) ──────────────
_install_systemd() {
    if ! command -v systemctl >/dev/null 2>&1 || ! systemctl --user status >/dev/null 2>&1; then
        warn "systemd-user not available — skipping opencode-web autostart"
        return 0
    fi

    local opencode_bin
    opencode_bin="$(command -v opencode)"

    local env_file="$HOME/.config/opencode/web.env"
    if [[ ! -f "$env_file" ]]; then
        mkdir -p "$(dirname "$env_file")"
        cat > "$env_file" <<'ENVEOF'
OPENCODE_SERVER_USERNAME=cb
OPENCODE_SERVER_PASSWORD=your-secret-here
ENVEOF
        warn "created $env_file — set a real password before starting the service"
    fi

    local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p "$unit_dir"
    cat > "$unit_dir/opencode-web.service" <<EOF
[Unit]
Description=OpenCode Web UI
After=default.target

[Service]
EnvironmentFile=${env_file}
ExecStart=${opencode_bin} web --hostname 0.0.0.0 --port 4096
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now opencode-web.service 2>/dev/null \
        && ok "opencode-web systemd service enabled" \
        || warn "systemd enable failed (non-fatal)"
}

_web_autostart=false
if [[ "$(profile_tag)" == "server-headless" ]]; then
    _web_autostart=true
elif [[ "$(config_module_state "opencode-web-autostart" "false")" == "enabled" ]]; then
    _web_autostart=true
fi

if $_web_autostart; then
    if [[ "$(uname -s)" == "Linux" ]]; then
        ( _install_systemd ) || warn "opencode-web setup failed (non-fatal)"
    else
        warn "opencode-web autostart only supported on Linux (systemd) — skipping"
    fi
fi
