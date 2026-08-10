# Project: The Higgins Pipeline (Global Memory & Synthesis)
# Status: Operational — kb-mcp v2 live, higgins package in progress
# Last Updated: 2026-08-10

## Goal
Create a "Digital Twin" knowledge engine that captures raw data from all workstations, synthesizes it on a central server (SuperBro) using a local LLM, and provides surgical retrieval via an MCP server.

## Current Architecture
- **Senses (Capture):** Two capture layers feeding `~/Vaults/Higgins/AI/_ops`:
  - `mem` CLI tool (manual) — appends context-aware notes to `AI/_ops/mem/`.
  - `deja sync export` (automatic) — dumps session history as JSONL batches to `AI/_ops/deja/<hostname>/`. Secrets redacted at export time. Incremental with watermarks.
- **Metabolism (Synthesis):** Bash "Janitor" on SuperBro — daily cron job to process `_ops` into the structured Vault. Handles both mem scraps and deja JSONL batches. Local variant (monthly refresh workflow) implemented in `~/dotfiles/scripts/` (janitor.sh + kb-review.sh + kb-refresh.sh).
- **Consciousness (Retrieval):** MCP servers — kb-mcp v2 for vault queries (deployed: local for Cursor via `.cursor/mcp.minimal.json`, remote on SuperBro `http://100.100.1.50:8765/mcp` for PI). Zero tokens at session start — agents use `kb_search` on demand.
- **Index/Telemetry:** `higgins/` Python package (sqlite-backed) — Steps 1–2 done: package scaffold, `config.py`, `vault.py`, `index.py`, janitor subpackage (orchestrator/triager/indexer). kb-mcp v2 feeds it write counters (`~/.cache/higgins/meta.json`).
- **Transport:** Syncthing "One-Way Valve" (Workstations: Send Only → SuperBro: Receive Only) for the `~/Vaults/Higgins/` folder.

## Ops Directory Structure
```
~/Vaults/Higgins/AI/_ops/
  mem/                          ← manual notes (from mem tool)
    scraps-YYYY-MM-DD.md
  deja/                         ← automatic session history (from deja sync)
    monsterbro/                 ← per-hostname to avoid cross-machine collision
      deja-sync-<hash>-<ts>.jsonl
    superbro/
    linuxbro/
    _processed/                 ← Janitor moves files here after synthesis
  curator-reports/              ← vault health reports
  digest-*.md                   ← session digests
```

## Completed
- [x] Spec defined and locked.
- [x] Unified `~/Vaults/Higgins` structure created.
- [x] Context-aware `mem` tool deployed and fixed to write to `~/Vaults/Higgins/AI/_ops/mem/`.
- [x] SuperBro prepared: Ollama installed, `llama3:8b` pulled, Bun installed.
- [x] Initial Vault migration to SuperBro completed via Zip/SCP.
- [x] deja-vu integration planned and added to spec.
- [x] deja-vu installed and indexed on macbro (1089 Cursor + 61 OpenCode sessions).
- [x] Inbox directory structure created: `mem/`, `deja/macbro/`, `deja/_processed/`.
- [x] deja sync export tested: 101 records exported to JSONL.
- [x] OpenCode deja-sync plugin created (session.idle trigger, retry, rotation, non-blocking).
- [x] **MCP-first architecture:** kb-mcp server built, kb-load + wrappers deleted, AGENTS.md + core.mdc updated.
- [x] **kb-mcp v2:** chunking, hot cache (1h TTL), tier-filtered `kb_search` (FTS5/BM25), higgins write counter. Verified with Cursor.
- [x] **Vault restructure:** Inbox/deja/ → AI/_ops/deja/, Me/Brains/ → AI/projects/, mem path updated.
- [x] **higgins package:** Step 1 (scaffold + config + CLI) and Step 2 (vault.py, index.py, write counting). Chose sqlite over postgres.
- [x] **Monthly refresh workflow:** janitor.sh + janitor.conf + kb-review.sh + kb-refresh.sh (per kb-evolution-plan).

## In-Progress / Next Steps
1. **Janitor Expansion:**
   - [ ] Expand janitor to read from `AI/_ops/mem/` and classify entries
   - [ ] Route work items → AI projects, personal items → Me/
   - [ ] Set up janitor cron on SuperBro (pending — server-side)
2. **Remote Setup:**
   - [ ] Install ZenNotes MCP on SuperBro
3. **higgins as MCP (future):** grow a native MCP server entry inside the `higgins/` package; kb-mcp wrapper retires when that lands. Naming: keep `kb-mcp` as the deployed wrapper name until then (see Decisions).
4. **Documentation:** Update remaining path references across vault files.

## Key Paths & Configs
- **Workstation `mem` path:** `~/dotfiles/bin/mem` → `~/Vaults/Higgins/AI/_ops/mem/`
- **deja-vu index:** `~/.cache/deja/index.db` (per workstation, local only)
- **deja-sync plugin:** `~/.config/opencode/plugins/deja-sync.js`
- **deja-sync logs:** `~/.config/opencode/logs/deja-sync.log` (rotated at 10MB, keeps 3 backups)
- **SuperBro Janitor path:** `~/Vaults/Higgins/AI/tools/janitor.sh`
- **Local MCP server:** `~/dotfiles/scripts/kb-mcp` (kb-mcp v2)
- **Remote MCP endpoint:** `http://100.100.1.50:8765/mcp` (SuperBro, used by PI)
- **Cursor MCP config:** `~/.cursor/mcp.minimal.json`
- **PI MCP config:** `~/.config/pi/agent/mcp.json`
- **Vault Root:** `~/Vaults/Higgins`
- **AI Vault:** `~/Vaults/Higgins/AI`
- **Personal Vault:** `~/Vaults/Higgins/Me`
- **Ops Directory:** `~/Vaults/Higgins/AI/_ops`
- **Model:** `llama3:8b` (Local Ollama)

## Janitor Input Format

### mem scraps (existing)
```markdown
---
Time: 14:32
Note: chose sqlite over postgres for higgins
Path: /Users/christian/dotfiles
Repo: dotfiles
LastChange: some commit message
---
```

### deja-vu JSONL batches (new)
```json
{"harness":"opencode","session_id":"abc123","project":"dotfiles","role":"assistant","text":"fixed by reloading jwks cache...","time":"2026-07-14T12:00:00Z"}
```
Each line is one message. Group by `session_id` to reconstruct full sessions. Already redacted. Watermarked export = idempotent re-runs.

## Agent Integration
Each workstation gets deja-vu as a **local agent memory layer** independent of Higgins:
- OpenCode plugin: auto-recalls relevant past sessions at SessionStart (2KB context cap)
- MCP tools: `recall` (snippets) and `recall_context` (markdown digest) available during sessions
- AGENTS.md updated with recall instructions so agents proactively use memory

`deja sync` bridges local memory → Higgins: the same data agents recall locally also feeds the centralized vault via Syncthing.

### deja-sync Plugin (OpenCode)
**Location:** `~/.config/opencode/plugins/deja-sync.js` (Global, auto-loaded)

**Trigger:** `session.idle` event (when OpenCode session ends)

**Behavior:**
- Executes `deja sync export ~/Vaults/Higgins/AI/_ops/deja/macbro/` in background
- Non-blocking: OpenCode session closes immediately
- Retry logic: Up to 3 attempts with 1-second delay between retries
- On final failure: Logs error and swallows (no notifications)

**Logging:**
- File: `~/.config/opencode/logs/deja-sync.log`
- Format: ISO 8601 timestamps + status (✓ success / ✗ failure / ERROR)
- Rotation: Automatic at 10MB, keeps 3 previous rotations (`.1`, `.2`, `.3`)
- Performance: Async, non-blocking, minimal overhead

## Decisions Made
- [x] **`mem` path:** Fixed to write to `~/Vaults/Higgins/AI/_ops/mem/` ✓
- [x] **Sync frequency:** OpenCode plugin triggers `deja sync export` on `session.idle` event ✓
- [x] **Storage:** sqlite over postgres for higgins ✓
- [x] **Naming:** keep `kb-mcp` as deployed wrapper name; higgins package owns product identity. Rename when higgins ships its own MCP entry (single coordinated change: file + cursor config + SuperBro remote).
- [ ] **Janitor model for sessions:** `llama3:8b` for both mem scraps and deja sessions (or larger for sessions — TBD)
