#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

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
