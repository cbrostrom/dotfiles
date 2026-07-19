# Project: The Higgins Pipeline (Global Memory & Synthesis)
# Status: Implementation Phase
# Last Updated: 2026-07-18

## 🎯 Goal
Create a "Digital Twin" knowledge engine that captures raw data from all workstations, synthesizes it on a central server (SuperBro) using a local LLM, and provides surgical retrieval via an MCP server.

## 🛠 Current Architecture
- **Senses (Capture):** Two capture layers feeding `~/Vaults/Higgins/AI/_ops`:
  - `mem` CLI tool (manual) $\rightarrow$ Appends context-aware notes to `AI/_ops/mem/`.
  - `deja sync export` (automatic) $\rightarrow$ Dumps session history as JSONL batches to `AI/_ops/deja/<hostname>/`. Secrets redacted at export time. Incremental with watermarks.
- **Metabolism (Synthesis):** Bash "Janitor" on SuperBro $\rightarrow$ Daily cron job to process `_ops` into the structured Vault. Handles both mem scraps and deja JSONL batches, classifying entries (work → AI projects, personal → Me/).
- **Consciousness (Retrieval):** MCP servers $\rightarrow$ kb-mcp for vault queries, ZenNotes for personal notes. Zero tokens at session start.
- **Transport:** Syncthing "One-Way Valve" (Workstations: Send Only $\rightarrow$ SuperBro: Receive Only) for the `~/Vaults/Higgins/` folder.

## 📂 Ops Directory Structure
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

## ✅ Completed
- [x] Spec defined and locked.
- [x] Unified `~/Vaults/Higgins` structure created.
- [x] Context-aware `mem` tool deployed and fixed to write to `~/Vaults/Higgins/AI/_ops/mem/`.
- [x] SuperBro prepared: Ollama installed, `llama3:8b` pulled, Bun installed.
- [x] Initial Vault migration to SuperBro completed via Zip/SCP.
- [x] deja-vu integration planned and added to spec.
- [x] deja-vu installed and indexed on macbro (1089 Cursor + 61 OpenCode sessions).
- [x] Inbox directory structure created: `mem/`, `deja/macbro/`, `deja/_processed/`.
- [x] deja sync export tested: 101 records exported to JSONL.
- [x] OpenCode deja-sync plugin created with:
  - [x] `session.idle` event handler
  - [x] 3-retry logic (1s delay between attempts)
  - [x] Log rotation (10MB max, keeps 3 rotations)
  - [x] Non-blocking background execution
  - [x] Logging to `~/.config/opencode/logs/deja-sync.log`
- [x] **MCP-first architecture:** kb-mcp server built, kb-load + wrappers deleted, AGENTS.md + core.mdc updated.
- [x] **Vault restructure:** Inbox/deja/ → AI/_ops/deja/, Me/Brains/ → AI/projects/, mem path updated.

## 🚧 In-Progress / Next Steps
1. **Janitor Expansion:**
   - [ ] Expand janitor to read from `AI/_ops/mem/` and classify entries
   - [ ] Route work items → AI projects, personal items → Me/
2. **Remote Setup:**
   - [ ] Install ZenNotes MCP on SuperBro
   - [ ] Set up janitor cron on SuperBro
3. **Verification:** Test kb-mcp tools with Cursor to ensure on-demand vault access works.
4. **Documentation:** Update remaining path references across vault files.

## 🔑 Key Paths & Configs
- **Workstation `mem` path:** `~/dotfiles/bin/mem` → `~/Vaults/Higgins/AI/_ops/mem/`
- **deja-vu index:** `~/.cache/deja/index.db` (per workstation, local only)
- **deja-sync plugin:** `~/.config/opencode/plugins/deja-sync.js`
- **deja-sync logs:** `~/.config/opencode/logs/deja-sync.log` (rotated at 10MB, keeps 3 backups)
- **SuperBro Janitor path:** `~/Vaults/Higgins/AI/tools/janitor.sh`
- **Vault Root:** `~/Vaults/Higgins`
- **AI Vault:** `~/Vaults/Higgins/AI`
- **Personal Vault:** `~/Vaults/Higgins/Me`
- **Ops Directory:** `~/Vaults/Higgins/AI/_ops`
- **MCP Config:** `~/.cursor/mcp.minimal.json` (kb-mcp + zennotes servers)
- **Model:** `llama3:8b` (Local Ollama)

## 📐 Janitor Input Format

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

## 🧠 Agent Integration
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

## 📋 Decisions Made
- [x] **`mem` path:** Fixed to write to `~/Vaults/Higgins/AI/_ops/mem/` ✓
- [x] **Sync frequency:** OpenCode plugin triggers `deja sync export` on `session.idle` event ✓
- [ ] **Janitor model for sessions:** `llama3:8b` for both mem scraps and deja sessions (or larger for sessions — TBD)
