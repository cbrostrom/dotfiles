# Brain: dotfiles
_Updated: 2026-06-15 14:30_

## Current State
- CloudCLI running via pm2 on port 8686, proxied via Caddy `ai.local:8443`
- Claude provider auth broken: newer Claude Code stores OAuth in macOS Keychain, cloudcli reads `.credentials.json` (doesn't exist)
- Cursor falls back as active provider — unwanted

## Open Decisions
- **CloudCLI fix (parked)**: needs API key OR cloudcli update to read Keychain — no personal API key available (enterprise AKQA sub)
- brain-load/save hooks still target repo-local `.claude/brain.md` — rewrite to `~/Vaults/Brain/Brains/<slug>.md` pending
- Wire Syncthing: Mac vault → SuperBro

## Gotchas
- cloudcli `claude-auth.provider.ts` checks `.credentials.json` → Keychain auth = invisible to it
- `claude auth status` shows logged in but cloudcli still unauthenticated — different auth storage
- cloudcli JWT (username/password session) expired 2026-05-19 → clear browser localStorage + re-login if UI issues

## Next Steps
- When API key available: `echo "ANTHROPIC_API_KEY=sk-ant-..." > /opt/homebrew/lib/node_modules/@cloudcli-ai/cloudcli/.env && pm2 restart cloudcli-ui`
- OR: file cloudcli issue — they need Keychain support for newer Claude Code
- Bootstrap SuperBro with cloudcli only after auth fixed on Mac

## Git Snapshot
 .claude/CLAUDE.md                    | 21 +++++++++-------
 .claude/RTK.md                       |  6 ++---
 .claude/agent-style/claude-code.md   | 16 ++++++-------
 .claude/brain.md                     | 46 +++++++++++++++++++++---------------
 .claude/coding-principles.md         | 17 +++++++------
 .claude/devices/GY-M-WHKK2PF6N7.json |  2 +-
 .claude/hooks/brain-load.sh          | 29 ++++++++++++++++++++---
 .claude/hooks/brain-save-inject.sh   | 34 +++++++++++++++++++-------
 .claude/hooks/statusline.sh          |  5 ++--
 .claude/settings.base.json           | 17 ++++---------
 .claude/tools.macos.md               |  2 +-
 .shared-rules/engram-graphiti.md     | 45 ++++++++++++++++-------------------
 dotfiles.sh                          |  3 ++-
 13 files changed, 140 insertions(+), 103 deletions(-)
