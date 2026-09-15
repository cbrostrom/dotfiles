#!/usr/bin/env bun
/**
 * Session Extract — Higgins memory pipeline
 *
 * Reads PI session JSONL files, extracts structured summaries,
 * writes markdown to vault for Syncthing sync + context-mode indexing.
 *
 * Usage:
 *   bun run extract.ts                    # extract all unprocessed sessions
 *   bun run extract.ts --since 2026-07-01 # extract sessions since date
 *   bun run extract.ts --project dotfiles # extract only specific project
 *   bun run extract.ts --dry-run          # preview without writing
 *   bun run extract.ts --reindex          # re-extract all (overwrite existing)
 */

import { readdir, readFile, writeFile, mkdir } from "fs/promises";
import { existsSync } from "fs";
import { join, basename } from "path";
import { homedir } from "os";

// Minimal ambient declaration for the one Bun global this script touches —
// avoids pulling in the full bun-types package/tsconfig just for this.
declare const Bun: { file(path: string): { lastModified: number } };

const PI_SESSIONS_DIR = join(homedir(), ".pi/agent/sessions");
const VAULT_AI = process.env.VAULT_AI || join(homedir(), "Vaults/Higgins/AI");
const VAULT_SESSIONS_DIR = join(VAULT_AI, "sessions");
const STATE_FILE = join(VAULT_SESSIONS_DIR, ".extract-state.json");
/** P2: brain-file updates go through the Higgins inbox as durable events;
 * `higgins ingest` is the single writer that applies them. */
const VAULT_INBOX = process.env.HIGGINS_INBOX || join(homedir(), "Vaults/Higgins/Inbox");

// Per-run caps: keep raw regex extraction from flooding curated brain files.
// Ongoing pruning is Higgins' job (idle-kb-tidy hook runs prune + compact);
// this just stops admitting an unbounded amount of noise in one pass.
const MAX_GOTCHAS_PER_RUN = 5;
const MAX_CURRENT_PER_RUN = 5;

// Real PI session JSONL schema (verified against live session files —
// NOT the tool_use/tool_result/exitCode shape an earlier version assumed).
interface ContentBlock {
  type: string; // "text" | "thinking" | "toolCall" | "image" | ...
  text?: string;
  thinking?: string;
  name?: string; // toolCall
  arguments?: Record<string, unknown>; // toolCall
}

interface SessionEntry {
  type: string; // "session" | "message" | "model_change" | ...
  id?: string;
  timestamp?: string;
  cwd?: string; // present on the "session" entry only
  version?: number;
  message?: {
    role: string; // "user" | "assistant" | "toolResult"
    content?: ContentBlock[];
    toolCallId?: string;
    toolName?: string;
    details?: { error?: string; [k: string]: unknown };
    isError?: boolean;
  };
  modelId?: string;
}

interface SessionSummary {
  id: string;
  date: string;
  project: string;
  model: string;
  duration: string;
  intent: string;
  decisions: string[];
  filesTouched: string[];
  errors: Array<{ error: string; solution: string }>;
  learnings: string[];
  messageCount: number;
  toolCalls: number;
  firstUserMessage: string;
  lastAssistantMessage: string;
}

interface ExtractState {
  processed: Record<string, string>; // sessionId -> lastModified ISO
}

function parseArgs() {
  const args = process.argv.slice(2);
  const opts: {
    since?: string;
    project?: string;
    dryRun: boolean;
    reindex: boolean;
  } = { dryRun: false, reindex: false };

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--since" && args[i + 1]) opts.since = args[++i];
    if (args[i] === "--project" && args[i + 1]) opts.project = args[++i];
    if (args[i] === "--dry-run") opts.dryRun = true;
    if (args[i] === "--reindex") opts.reindex = true;
  }
  return opts;
}

async function loadState(): Promise<ExtractState> {
  if (existsSync(STATE_FILE)) {
    return JSON.parse(await readFile(STATE_FILE, "utf-8"));
  }
  return { processed: {} };
}

async function saveState(state: ExtractState): Promise<void> {
  await writeFile(STATE_FILE, JSON.stringify(state, null, 2));
}

// ── Session discovery ───────────────────────────────────────────────────────

/**
 * Best-effort fallback slug decoder for session directories that lack a
 * "session" entry with `cwd` (very old sessions). PI encodes a cwd's `/` as
 * `-`, which is ambiguous with a literal `-` already in a directory name
 * (e.g. "stellar-shopify" vs a path separator) — this WILL misattribute
 * dashed project names sometimes. Prefer the real `cwd` field whenever it's
 * available (see discoverSessions).
 */
function decodeSlugFromDirName(dirName: string): string {
  const decoded = dirName
    .replace(/^--Users-Christian\.Brostrom--$/, "home")
    .replace(/^--Users-Christian\.Brostrom-/, "")
    .replace(/--$/, "")
    .replace(/-/g, "/");
  return decoded.split("/").pop() || dirName;
}

async function discoverSessions(
  since?: string,
  project?: string
): Promise<Array<{ path: string; id: string; project: string; mtime: Date }>> {
  const sessions: Array<{
    path: string;
    id: string;
    project: string;
    mtime: Date;
  }> = [];

  const projects = await readdir(PI_SESSIONS_DIR);

  for (const projDir of projects) {
    const projPath = join(PI_SESSIONS_DIR, projDir);
    if (!existsSync(projPath)) continue;

    const fallbackSlug = decodeSlugFromDirName(projDir);

    const files = await readdir(projPath).catch(() => []);
    for (const file of files) {
      if (!file.endsWith(".jsonl")) continue;

      const filePath = join(projPath, file);
      if (!existsSync(filePath)) continue;

      const info = Bun.file(filePath);
      const mtime = new Date(info.lastModified);

      if (since) {
        const sinceDate = new Date(since);
        if (mtime < sinceDate) continue;
      }

      // Resolve the real project slug from the session's own cwd field
      // rather than reverse-engineering the dash-encoded directory name.
      let slug = fallbackSlug;
      const firstLine = await firstLineOf(filePath);
      if (firstLine) {
        try {
          const parsed = JSON.parse(firstLine) as SessionEntry;
          if (parsed.type === "session" && parsed.cwd) {
            slug = basename(parsed.cwd);
          }
        } catch {
          // fall through to fallbackSlug
        }
      }

      if (project && !slug.toLowerCase().includes(project.toLowerCase())) {
        continue;
      }

      const sessionId = file.replace(".jsonl", "").split("_").pop() || file;

      sessions.push({ path: filePath, id: sessionId, project: slug, mtime });
    }
  }

  return sessions.sort((a, b) => a.mtime.getTime() - b.mtime.getTime());
}

async function firstLineOf(filePath: string): Promise<string | null> {
  const content = await readFile(filePath, "utf-8");
  const newlineIdx = content.indexOf("\n");
  const line = newlineIdx === -1 ? content : content.slice(0, newlineIdx);
  return line.trim() || null;
}

// ── Session parsing ─────────────────────────────────────────────────────────

async function parseSession(filePath: string): Promise<SessionEntry[]> {
  const content = await readFile(filePath, "utf-8");
  const lines = content.split("\n").filter(Boolean);
  const entries: SessionEntry[] = [];

  for (const line of lines) {
    try {
      entries.push(JSON.parse(line));
    } catch {
      // Skip malformed lines
    }
  }

  return entries;
}

function extractTextFromContent(content: ContentBlock[]): string {
  return content
    .filter((c) => c.type === "text" && c.text)
    .map((c) => c.text!)
    .join("\n");
}

function extractThinkingFromContent(content: ContentBlock[]): string {
  return content
    .filter((c) => c.type === "thinking" && c.thinking)
    .map((c) => c.thinking!)
    .join("\n");
}

/** Combined reasoning+visible text for an assistant turn — decisions and
 * learnings can show up in either, not just extended-thinking blocks. */
function extractReasoningText(content: ContentBlock[]): string {
  return [extractThinkingFromContent(content), extractTextFromContent(content)]
    .filter(Boolean)
    .join("\n");
}

const FILE_MUTATION_TOOLS = new Set(["edit", "write", "multiedit"]);

/** Files actually touched, read from real toolCall arguments (path/file_path)
 * rather than guessed from prose. Falls back to a light regex scan over the
 * conversation text only when no tool calls are present at all (e.g. a
 * discussion-only session). */
function extractFilePaths(entries: SessionEntry[], allText: string): string[] {
  const paths = new Set<string>();

  for (const entry of entries) {
    if (entry.type !== "message") continue;
    const content = entry.message?.content || [];
    for (const block of content) {
      if (block.type !== "toolCall") continue;
      const name = (block.name || "").toLowerCase();
      if (!FILE_MUTATION_TOOLS.has(name)) continue;
      const args = block.arguments || {};
      const path = (args.path || args.file_path) as string | undefined;
      if (path) paths.add(path);
    }
  }

  if (paths.size > 0) return Array.from(paths).slice(0, 10);

  // Fallback: no recognized tool calls in this session — best-effort regex.
  const patterns = [
    /(?:^|\s)([\w/.-]+\.(?:ts|tsx|js|jsx|json|md|yaml|yml|css|scss|html|py|rb|go|rs|sh))\b/g,
    /(?:src|app|lib|components?|pages?|routes?|utils?|helpers?)\/[\w/.-]+/g,
  ];
  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(allText)) !== null) {
      const path = match[1] || match[0];
      if (path.length > 3 && !path.startsWith("node_modules")) {
        paths.add(path.trim());
      }
    }
  }
  return Array.from(paths).slice(0, 10);
}

/** Errors read from real toolResult messages (role: "toolResult",
 * isError: true) — the previous exitCode/tool_result shape never matched
 * the actual schema and this extraction was silently a no-op. */
function extractErrors(entries: SessionEntry[]): Array<{ error: string; solution: string }> {
  const errors: Array<{ error: string; solution: string }> = [];

  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    if (entry.type !== "message" || entry.message?.role !== "toolResult") continue;
    if (!entry.message.isError) continue;

    const content = entry.message.content || [];
    const text = extractTextFromContent(content) || entry.message.details?.error || "";
    if (!text) continue;

    let solution = "";
    for (let j = i + 1; j < Math.min(i + 5, entries.length); j++) {
      const next = entries[j];
      if (next.type === "message" && next.message?.role === "assistant") {
        const reasoning = extractReasoningText(next.message.content || []);
        if (reasoning) {
          solution = truncateAtWord(reasoning, 200);
          break;
        }
      }
    }

    errors.push({
      error: truncateAtWord(text, 150),
      solution: solution || "No solution recorded",
    });
  }

  return errors.slice(0, 5);
}

const DECISION_PATTERNS = [
  /(?:decided|chose|going with|instead of|rather than|picked)\s+(.{20,100})/gi,
  /(?:because|since|given that)\s+(.{20,100})/gi,
];

const LEARNING_PATTERNS = [
  /(?:learned|realized|turns out|important to note)\s+(.{20,150})/gi,
  /(?:gotcha|pitfall|watch out|be careful)\s+(.{20,150})/gi,
  /(?:note:|NB:)\s+(.{20,150})/gi,
];

function truncateAtWord(text: string, maxLen: number): string {
  const trimmed = collapseWhitespace(text);
  if (trimmed.length <= maxLen) return trimmed;
  const cut = trimmed.slice(0, maxLen);
  const lastSpace = cut.lastIndexOf(" ");
  return (lastSpace > maxLen * 0.6 ? cut.slice(0, lastSpace) : cut).trim() + "…";
}

/** Collapse raw tool-output whitespace (multi-line ls/npm/error dumps) into a
 * single line — otherwise a bullet in gotchas.md/current.md ends up spanning
 * several physical lines and corrupts the list structure. */
function collapseWhitespace(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

function extractDecisions(entries: SessionEntry[]): string[] {
  const decisions: string[] = [];

  for (const entry of entries) {
    if (entry.type !== "message" || entry.message?.role !== "assistant") continue;
    const reasoning = extractReasoningText(entry.message.content || []);
    if (!reasoning) continue;

    for (const pattern of DECISION_PATTERNS) {
      let match;
      while ((match = pattern.exec(reasoning)) !== null) {
        const decision = truncateAtWord(match[0], 150);
        if (!decisions.includes(decision)) decisions.push(decision);
      }
    }
  }

  return decisions.slice(0, 5);
}

function extractLearnings(entries: SessionEntry[]): string[] {
  const learnings: string[] = [];

  for (const entry of entries) {
    if (entry.type !== "message" || entry.message?.role !== "assistant") continue;
    const reasoning = extractReasoningText(entry.message.content || []);
    if (!reasoning) continue;

    for (const pattern of LEARNING_PATTERNS) {
      let match;
      while ((match = pattern.exec(reasoning)) !== null) {
        const learning = truncateAtWord(match[0], 200);
        if (!learnings.includes(learning)) learnings.push(learning);
      }
    }
  }

  return learnings.slice(0, 5);
}

// ── Summarization ───────────────────────────────────────────────────────────

function summarizeSession(
  entries: SessionEntry[],
  project: string,
  sessionId: string
): SessionSummary | null {
  if (entries.length === 0) return null;

  const sessionEntry = entries.find((e) => e.type === "session");
  const date = sessionEntry?.timestamp
    ? new Date(sessionEntry.timestamp).toISOString()
    : "unknown";

  const modelEntry = entries.find((e) => e.type === "model_change");
  const model = modelEntry?.modelId || "unknown";

  const firstTimestamp = entries[0]?.timestamp ? new Date(entries[0].timestamp).getTime() : 0;
  const lastTimestamp = entries[entries.length - 1]?.timestamp
    ? new Date(entries[entries.length - 1].timestamp).getTime()
    : 0;
  const durationMs = lastTimestamp - firstTimestamp;
  const durationMin = Math.round(durationMs / 60000);
  const duration =
    durationMin < 60 ? `${durationMin}m` : `${Math.floor(durationMin / 60)}h ${durationMin % 60}m`;

  const userMessages = entries
    .filter((e) => e.type === "message" && e.message?.role === "user")
    .map((e) => extractTextFromContent(e.message?.content || []))
    .filter(Boolean);

  const assistantMessages = entries
    .filter((e) => e.type === "message" && e.message?.role === "assistant")
    .map((e) => extractTextFromContent(e.message?.content || []))
    .filter(Boolean);

  const toolCalls = entries.filter(
    (e) => e.type === "message" && e.message?.role === "assistant"
  ).length;

  const firstUserMessage = userMessages[0] || "";
  const intent = firstUserMessage.slice(0, 200).replace(/\n/g, " ");

  const allText = [...userMessages, ...assistantMessages].join("\n");
  const filesTouched = extractFilePaths(entries, allText);

  const decisions = extractDecisions(entries);
  const errors = extractErrors(entries);
  const learnings = extractLearnings(entries);

  const lastAssistantMessage = assistantMessages[assistantMessages.length - 1] || "";

  return {
    id: sessionId,
    date,
    project,
    model,
    duration,
    intent,
    decisions,
    filesTouched,
    errors,
    learnings,
    messageCount: userMessages.length + assistantMessages.length,
    toolCalls,
    firstUserMessage: firstUserMessage.slice(0, 500),
    lastAssistantMessage: lastAssistantMessage.slice(0, 500),
  };
}

// ── Markdown generation ─────────────────────────────────────────────────────

function generateMarkdown(summary: SessionSummary): string {
  const lines: string[] = [];

  lines.push("---");
  lines.push(`session_id: ${summary.id}`);
  lines.push(`date: ${summary.date}`);
  lines.push(`project: ${summary.project}`);
  lines.push(`model: ${summary.model}`);
  lines.push(`duration: ${summary.duration}`);
  lines.push(`messages: ${summary.messageCount}`);
  lines.push(`tool_calls: ${summary.toolCalls}`);
  lines.push("---");
  lines.push("");

  lines.push(`# Session: ${summary.project} — ${summary.date}`);
  lines.push("");

  if (summary.intent) {
    lines.push("## Intent");
    lines.push(summary.intent);
    lines.push("");
  }

  if (summary.decisions.length > 0) {
    lines.push("## Decisions");
    for (const decision of summary.decisions) lines.push(`- ${decision}`);
    lines.push("");
  }

  if (summary.filesTouched.length > 0) {
    lines.push("## Files Touched");
    for (const file of summary.filesTouched) lines.push(`- \`${file}\``);
    lines.push("");
  }

  if (summary.errors.length > 0) {
    lines.push("## Errors & Solutions");
    for (const { error, solution } of summary.errors) {
      lines.push(`### Error`);
      lines.push(error);
      lines.push(`### Solution`);
      lines.push(solution);
      lines.push("");
    }
  }

  if (summary.learnings.length > 0) {
    lines.push("## Learnings");
    for (const learning of summary.learnings) lines.push(`- ${learning}`);
    lines.push("");
  }

  if (summary.lastAssistantMessage) {
    lines.push("## Summary");
    lines.push(summary.lastAssistantMessage.slice(0, 300));
    lines.push("");
  }

  return lines.join("\n");
}

// ── Brain file updates (zero-token auto-learning) ──────────────────────────

/** Lines that talk *about* the gotcha/current tooling itself rather than
 * describing an actual fact — these regexes reliably fire on conversations
 * about the memory pipeline (e.g. this very script) and pollute the vault. */
const META_NOISE_PATTERN = /\b(higgins|kb)\s+(gotcha|current|save|digest|next)\b|`gotcha|`kb |`higgins /i;

function normalize(line: string): string {
  return line.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}


/** P2: emit brain-file candidates as one durable inbox event per session.
 * Dedupe and application happen in `higgins ingest` (single writer), so this
 * function performs no direct read-modify-write on vault Markdown. */
async function updateBrainFiles(
  summary: SessionSummary,
  budgets: { gotchas: { remaining: number }; current: { remaining: number } }
): Promise<string[]> {
  // Only promote errors that actually resolved to something — a transient
  // "Command aborted" with no recorded fix isn't a durable trap worth
  // keeping forever, it's session noise.
  const gotchaCandidates: string[] = [
    ...summary.errors
      .filter(({ solution }) => solution !== "No solution recorded" && solution.trim().length >= 20)
      .map(({ error, solution }) => `- ${error.slice(0, 100)} → ${solution.slice(0, 100)}`),
    ...summary.learnings
      .filter((l) => /gotcha|pitfall|watch out|be careful|don't|never|always|caveat/i.test(l))
      .map((l) => `- ${l}`),
  ].filter((l) => l.trim().length >= 20 && !META_NOISE_PATTERN.test(l));

  const currentCandidates: string[] = [
    ...summary.decisions
      .filter((d) => /prefer|always use|instead of|rather than|switched to/i.test(d))
      .map((d) => `- ${d}`),
    ...summary.learnings
      .filter((l) => /prefer|pattern|convention|style|workflow/i.test(l))
      .map((l) => `- ${l}`),
  ].filter((l) => l.trim().length >= 20 && !META_NOISE_PATTERN.test(l));

  if (gotchaCandidates.length === 0 && currentCandidates.length === 0) return [];

  const notes: string[] = [];
  const id = `pi-extract:${summary.id}`;
  const event = {
    id,
    created_at: new Date().toISOString(),
    source: "pi-extract",
    slug: "personal",
    gotcha_lines: gotchaCandidates.slice(0, Math.max(0, budgets.gotchas.remaining)),
    current_lines: currentCandidates.slice(0, Math.max(0, budgets.current.remaining)),
    gotcha_budget: Math.max(0, budgets.gotchas.remaining),
    current_budget: Math.max(0, budgets.current.remaining),
  };
  if (event.gotcha_lines.length === 0 && event.current_lines.length === 0) return [];

  await mkdir(VAULT_INBOX, { recursive: true });
  const safeName = id.replace(/[^a-zA-Z0-9._-]+/g, "-");
  await writeFile(join(VAULT_INBOX, `${safeName}.json`), JSON.stringify(event, null, 2) + "\n");
  notes.push(`inbox event +${event.gotcha_lines.length}g/${event.current_lines.length}c`);
  budgets.gotchas.remaining -= event.gotcha_lines.length;
  budgets.current.remaining -= event.current_lines.length;
  return notes;
}

// ── Logging with timestamps ────────────────────────────────────────────────

function log(msg: string): void {
  const iso = new Date().toISOString();
  console.log(`[${iso}] ${msg}`);
}

/** Run async work over items with bounded concurrency. Session parsing is
 * I/O-bound (file read + JSON parse per line); brain-file writes stay
 * strictly serial (see main) since they read-modify-write shared files. */
async function mapWithConcurrency<T, R>(
  items: T[],
  limit: number,
  fn: (item: T) => Promise<R>
): Promise<R[]> {
  const results: R[] = Array.from({ length: items.length });
  let next = 0;

  async function worker() {
    while (true) {
      const i = next++;
      if (i >= items.length) return;
      results[i] = await fn(items[i]);
    }
  }

  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

// ── Main ────────────────────────────────────────────────────────────────────

async function main() {
  const opts = parseArgs();
  const state = await loadState();
  const startTime = Date.now();
  const prevProcessedCount = Object.keys(state.processed).length;

  log("🔍 Discovering sessions...");
  const allSessions = await discoverSessions(opts.since, opts.project);
  log(`   Found ${allSessions.length} sessions`);
  log(`   Previously processed: ${prevProcessedCount} sessions`);

  const pending = allSessions.filter((session) => {
    if (opts.reindex) return true;
    const processedTime = state.processed[session.id];
    if (!processedTime) return true;
    return session.mtime > new Date(processedTime);
  });
  const skippedCount = allSessions.length - pending.length;

  // Parse + summarize in parallel (I/O-bound); writes happen serially below.
  const summarized = await mapWithConcurrency(pending, 8, async (session) => {
    log(`📝 Processing: ${session.id} (${session.project})`);
    const entries = await parseSession(session.path);
    const summary = summarizeSession(entries, session.project, session.id);
    return { session, summary };
  });

  // Run-wide budget: caps total additions across ALL sessions processed in
  // this invocation, not per session (a --reindex pass over 50+ sessions
  // would otherwise flood the file well past the cap).
  const budgets = {
    gotchas: { remaining: MAX_GOTCHAS_PER_RUN },
    current: { remaining: MAX_CURRENT_PER_RUN },
  };

  let extracted = 0;
  let emptySkipped = 0;

  for (const { session, summary } of summarized) {
    if (!summary) {
      log(`   ⚠️  Empty session, skipping: ${session.id}`);
      emptySkipped++;
      continue;
    }

    const markdown = generateMarkdown(summary);

    const dateParts = summary.date.split("-");
    const year = dateParts[0] || "unknown";
    const month = dateParts[1] || "01";
    const outDir = join(VAULT_SESSIONS_DIR, year, month);
    const timestamp = summary.date.split(".")[0].replace(/[T:]/g, "-");
    const shortId = summary.id.slice(0, 8);
    const outFile = join(outDir, `${timestamp}_${summary.project}_${shortId}.md`);

    if (opts.dryRun) {
      log(`   📋 Dry run — would write:`);
      log(`      ${outFile}`);
      log(`      ${summary.intent.slice(0, 80)}...`);
    } else {
      await mkdir(outDir, { recursive: true });
      await writeFile(outFile, markdown);
      log(`   ✅ Written: ${outFile}`);
      log(`      Timestamp: ${timestamp} | Project: ${summary.project} | ID: ${shortId}...`);
      log(`      Intent: ${summary.intent.slice(0, 60)}...`);

      const brainNotes = await updateBrainFiles(summary, budgets);
      if (brainNotes.length > 0) log(`   🧠 Brain updated: ${brainNotes.join(", ")}`);

      state.processed[session.id] = new Date().toISOString();
    }

    extracted++;
  }

  if (!opts.dryRun) {
    await saveState(state);
  }

  const elapsedMs = Date.now() - startTime;
  const newProcessedCount = Object.keys(state.processed).length;
  log(`\n📊 Summary:`);
  log(`   Extracted: ${extracted}`);
  log(`   Skipped: ${skippedCount + emptySkipped} (already processed: ${skippedCount}, empty: ${emptySkipped})`);
  log(`   Total processed state: ${prevProcessedCount} → ${newProcessedCount}`);
  log(`   Vault: ${VAULT_SESSIONS_DIR}`);
  log(`   Duration: ${(elapsedMs / 1000).toFixed(1)}s`);
}

main().catch((err) => {
  console.error("❌ Error:", err);
  process.exit(1);
});
