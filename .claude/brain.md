# Brain: dotfiles
_Updated: 2026-06-15 16:00_

## Current State
- statusline.sh: cost removed (per-session only, not useful)
- engram-graphiti.md removed from CLAUDE.md (cleanup)
- settings.base.json + statusline.sh modified this session

## Open Decisions
- Vault sync mechanism still deferred (LiveSync vs Syncthing vs hybrid)
- Brain skill build deferred — validate vault use first
- Old vault `~/Vaults/Christian/` retained for plugin config; delete after 1 week

## Gotchas
- `brain-load.sh` / `brain-save-inject.sh` still target repo-local `.claude/brain.md`, NOT vault `Brains/<slug>.md`
- LiveSync paused during restructure — must reconfigure CouchDB to new vault folder
- `.cost.total_cost_usd` in Claude Code hook payload = cost since session start (not wall-clock)

## Next Steps
- Rewrite `brain-load.sh` to target `~/Vaults/Brain/Brains/<slug>.md` via `$PWD → slug` table
- Reconfigure LiveSync on new Brain vault (or commit to sync decision first)
- Merge `Work/AKQA/Shopify/Fiskars/_dupe-from-Projects-Fiskars/` manually before new Fiskars notes

## Git Snapshot
 .claude/CLAUDE.md              |   1 -
 .claude/brain.md               |  32 ++++----
 .claude/hooks/statusline.sh    |  71 +++++++++--------
 .claude/hooks/wrap-reminder.sh |   4 +-
 .claude/settings.base.json     | 174 ++++++++++++++++++++++++++++++++--------
 5 files changed, 200 insertions(+), 82 deletions(-)
