# Memory consolidation plan — Higgins + DuckDB as the single brain

Status: draft for approval
Scope: Mac (daily driver) + CloudBro (remote compute). Design target for both, CloudBro-native from day one.

## 1. Goal

One memory system, one query surface. All memory-related lookups flow through Higgins;
DuckDB is Higgins' analytical index that cuts lookup token cost by an order of magnitude.

- Markdown vault stays the source of truth for anything curated.
- Passive session capture stays automatic (Deja) — agents never have to "remember to save".
- DuckDB files are derived, machine-local, rebuildable at any time with zero information
  loss. Nothing in a .duckdb file is ever authoritative.
- Remove competing query surfaces over time (Deja search frontend retires; its sync
  commands stay as capture plumbing).

## 2. Non-goals

- No vector database (scout-logged revisit condition unchanged: only if measured FTS5
  misses appear on a representative query set).
- No context-assembly layer (context-mode already fills that role, hook-enforced).
- No new MCP servers. Higgins MCP gains at most one tool (`duckdb`).
- No agent-facing raw SQL access. Agents call `higgins`; provenance and freshness come
  from the tool contract, not agent discipline.

## 3. Sync strategy — Syncthing-first

Transport: Syncthing for everything (vault AI/ + Me/, dotfiles working trees).

- Staggered file versioning enabled on every synced folder → `.stversions/` = rollback
  history without git ceremony.
- Git is demoted to optional insurance: a small auto-commit bot (fswatch + `git commit
  -am`, no push, every ~30 min with changes) may keep restore points on the dotfiles
  repo. It never syncs anything. Droppable without architectural impact.
- Dotfiles *activation* (stow, hook installs, module builds) stays pull-based and
  explicit. Synced files land instantly; nothing executes them automatically.

### 3.1 Anti-stomping rules (single-writer discipline)

Every synced artifact has exactly one producing machine side:

1. Ledger shards are per-machine: `ops/ledger/<machine>/ <machine>.ndjson`
   (e.g. `mac.ndjson`, `cloudbro.ndjson`). The Mac only ever writes `mac.ndjson`;
   CloudBro only ever writes `cloudbro.ndjson`. Syncthing replicates both, no
   concurrent-writer conflicts.
2. DuckDB files are never synced. `*.duckdb` and `*.duckdb.wal` go on the Syncthing
   ignore list. Each machine rebuilds its own from ledger + vault.
3. Curated vault markdown follows the existing Higgins write rule: only `higgins`
   (CLI/MCP) writes. Sessions/Markdown written on Mac stay Mac-written.
4. A `.stfolder`-sibling conflict file (`*.sync-conflict-*`) found in `ops/ledger/`
   or vault state files is a red flag: rebuilders must refuse to ingest it silently
   and report it.
5. Deja's `sync ssh <host> [--pull]` remains available for direct machine-to-machine
   capture pull when Syncthing is not appropriate (e.g. one-off backfill), but
   Syncthing is the standing transport.

### 3.2 Retention

Ledger NDJSON is append-only but NOT unbounded: `higgins ledger prune` drops raw
events older than a policy window (default 90 days) while keeping session summaries
and everything already projected/vaulted. History beyond that is disposable by design.

## 4. Layer architecture

```
L0  Capture (Deja, per machine, redacted by default)
     |  deja sync export <dir>           (JSONL: {harness, session_id, project, role, text, time})
     v
L1  Ledger  (vault: ops/ledger/<machine>/<machine>.ndjson, Syncthing-synced, sharded per machine)
     |  higgins ledger prune / status
     v
L2  Curated knowledge (existing vault tiers: projects/ modules/ infra/ personal/ sessions/)
     |  unchanged. Markdown is authoritative; DuckDB never replaces it.
     v
L3  Projections (LOCAL-ONLY, per machine):
     <vault>/ops/duckdb/brain-<hostname>.duckdb
     |  higgins duckdb rebuild  → re-derives from L1 + L2, stamps freshness
     v
L4  Query surface (single brain):
     higgins search            → FTS5 prose lookup (unchanged)
     higgins duckdb <SQL-verb> → structured/analytics lookup (new)
```

## 5. DuckDB schema (derived tables)

Every row carries provenance: `source_ref`, `doc_hash`, `indexed_at`, `source_rev`.

```sql
-- L2-derived: vault decisions (status from front-matter; never edited in-place here)
CREATE TABLE decisions (
  id VARCHAR, project VARCHAR, kind VARCHAR, status VARCHAR,
  title VARCHAR, summary VARCHAR, source_ref VARCHAR,   -- path + heading in vault
  created_at DATE, doc_hash VARCHAR, indexed_at TIMESTAMP
);

-- L1-derived: machine event stream
CREATE TABLE events (
  ts TIMESTAMP, machine VARCHAR, actor VARCHAR,        -- actor = agent profile / harness
  kind VARCHAR,                                        -- decision | session | repo | preference | ...
  project VARCHAR, payload JSON, source_ref VARCHAR, indexed_at TIMESTAMP
);

-- repo-facing analytics
CREATE TABLE repos (
  name VARCHAR, path VARCHAR, host VARCHAR, project VARCHAR,
  last_commit SHA/DATE as last_activity, tracked BOOLEAN, indexed_at TIMESTAMP
);

-- L2-derived: preferences live in personal/ markdown; this is a projection only
CREATE TABLE preferences (
  subject VARCHAR, key VARCHAR, value VARCHAR,
  confidence VARCHAR, source_ref VARCHAR, updated_at DATE, indexed_at TIMESTAMP
);

-- optional FTS mirror for blended queries
PRAGMA create_fts_index('fts_events', 'events', 'payload');  -- or equivalent via FTS5 side-table
```

### 5.1 Rebuild rules (learned from the dotfiles experiment)

- **Exclusion policy is config, not flags.** A checked-in exclusions list (transcript
  dumps, `*.bak`, lockfiles, summary/JSONL blobs, `.stversions`, `.git`) drives what
  the rebuild ingests. Ingest counts before/after exclusions get logged.
- **Path normalization is a single convention**: paths stored repo-relative per host,
  with the repo root recorded once per repos row. Symlink resolution is recorded
  (target path kept) so answers do not alias.
- **Freshness gate**: every query result carries freshness; a stale source (> policy
  age since `indexed_at` or source mtime newer than stamp) is surfaced as `stale`,
  and direct-edit answers re-verify the source file first.
- **Noise gate**: only session-grade captures become `events` (per-record kind
  detection from JSONL role/text shape). Raw transcript lines never enter DuckDB.

## 6. Agent-facing changes

1. New Higgins MCP tool: `duckdb` (bounded query verb set, max rows + token cap on
   responses). One tool, one contract, no raw arbitrary SQL surface for agents.
2. `.agents/AGENTS.md` gains the **Lookup discipline** section (global rule):

   - Prefer the smallest authoritative source: project metadata or scoped structured
     lookup before broad traversal or unsupported inference.
   - Skip lookup ceremony when the target is known and bounded; a tool call must beat
     a direct read in total task cost or accuracy.
   - Treat indexes/summaries as leads; surface freshness and revision; verify source
     before edits or material claims.
   - Progressive disclosure: locations/identifiers/compact excerpts first.
   - Structured/tabular lookups (git history, repo stats, events, decisions) go
     through the DuckDB projection; prose lookups through `higgins search`.
   - Durable changes remain proposals until approved.

3. Deja MCP tools (`deja_recall`, `deja_recall_context`) retire from hot-path MCP
   exposure once `higgins duckdb` parity is verified; mcporter keeps the server
   reachable during migration.

## 7. Rollout

| Phase | Deliverable | Size |
|---|---|---|
| P0 | Vault reorg: `ops/ledger/`, `ops/duckdb/` in gitignore paths, sharding rules | config only |
| P1 | `higgins ledger` (export-import Deja, prune, status) | ~150 LoC |
| P2 | `higgins duckdb` (rebuild, query, freshness report) | ~250 LoC |
| P3 | MCP tool + AGENTS.md lookup-discipline rule + skill doc update | ~40 LoC |
| P4 | Retire overlapping Deja reading path; keep `deja sync` as capture transport | config |

## 8. Success criteria

1. Delete any `.duckdb` on any machine → rebuild → identical answers (correctness).
2. Cross-project question ("what decisions happened for CloudBro last month", "which
   repos touched by agents this week") answered from one bounded SQL query with
   source refs (usability).
3. ≥25% less context/discovery effort vs the `higgins search + read` baseline for
   history/decision/repo questions, with equal-or-better correctness (efficiency).
4. No Syncthing conflict file is ever silently ingested (consistency).
5. No secret ever enters ledger or DuckDB (redaction on by default; denylist asserted
   in ingestion tests).

## 9. Risks

- Syncthing file versioning must actually be enabled — otherwise no rollback on the
  vault (mandatory setup step in P0, verified, not assumed).
- Deja export JSONL shape is the integration contract; if it drifts, ingestion must
  fail loudly rather than guess (schema check per file).
- DuckDB files are queryable databases of history — matched to vault sensitivity
  policy (no secrets per CloudBro boundary rules; .duckdb treated same as vault).
