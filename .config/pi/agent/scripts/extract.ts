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
import { join } from "path";
import { homedir } from "os";

// ── Config ──────────────────────────────────────────────────────────────────

const PI_SESSIONS_DIR = join(homedir(), ".pi/agent/sessions");
const VAULT_AI = process.env.VAULT_AI || join(homedir(), "Vaults/Higgins/AI");
const VAULT_SESSIONS_DIR = join(VAULT_AI, "sessions");
const STATE_FILE = join(VAULT_SESSIONS_DIR, ".extract-state.json");

// ── Types ───────────────────────────────────────────────────────────────────

interface SessionEntry {
  type: string;
  id?: string;
  timestamp?: string;
  cwd?: string;
  version?: number;
  message?: {
    role: string;
    content?: Array<{
      type: string;
      text?: string;
      thinking?: string;
      tool_use?: { name: string; input?: Record<string, unknown> };
      tool_result?: { content?: string; output?: string; exitCode?: number };
    }>;
  };
  command?: string;
  output?: string;
  exitCode?: number;
  modelId?: string;
  provider?: string;
  thinkingLevel?: string;
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

// ── Argument parsing ────────────────────────────────────────────────────────

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

// ── State management ────────────────────────────────────────────────────────

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

    // Decode project slug from directory name
    const projSlug = projDir
      .replace(/^--Users-Christian\.Brostrom--$/, "home")
      .replace(/^--Users-Christian\.Brostrom-/, "")
      .replace(/--$/, "")
      .replace(/-/g, "/")
      .split("/")
      .pop() || projDir;

    // Filter by project if specified
    if (project && !projSlug.toLowerCase().includes(project.toLowerCase())) {
      continue;
    }

    const files = await readdir(projPath).catch(() => []);
    for (const file of files) {
      if (!file.endsWith(".jsonl")) continue;

      const filePath = join(projPath, file);
      if (!existsSync(filePath)) continue;

      const info = Bun.file(filePath);
      const mtime = new Date(info.lastModified);

      // Filter by date if specified
      if (since) {
        const sinceDate = new Date(since);
        if (mtime < sinceDate) continue;
      }

      // Extract session ID from filename
      const sessionId = file.replace(".jsonl", "").split("_").pop() || file;

      sessions.push({
        path: filePath,
        id: sessionId,
        project: projSlug,
        mtime,
      });
    }
  }

  return sessions.sort((a, b) => a.mtime.getTime() - b.mtime.getTime());
}

// ── Session parsing ─────────────────────────────────────────────────────────

async function parseSession(
  filePath: string
): Promise<SessionEntry[]> {
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

function extractTextFromContent(
  content: Array<{ type: string; text?: string; thinking?: string }>
): string {
  return content
    .filter((c) => c.type === "text" && c.text)
    .map((c) => c.text!)
    .join("\n");
}

function extractThinkingFromContent(
  content: Array<{ type: string; thinking?: string }>
): string {
  return content
    .filter((c) => c.type === "thinking" && c.thinking)
    .map((c) => c.thinking!)
    .join("\n");
}

function extractFilePaths(text: string): string[] {
  const paths = new Set<string>();
  const patterns = [
    /(?:^|\s)([\w/.-]+\.(?:ts|tsx|js|jsx|json|md|yaml|yml|css|scss|html|py|rb|go|rs|sh))\b/g,
    /(?:src|app|lib|components?|pages?|routes?|utils?|helpers?)\/[\w/.-]+/g,
  ];

  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(text)) !== null) {
      const path = match[1] || match[0];
      if (path.length > 3 && !path.startsWith("node_modules")) {
        paths.add(path.trim());
      }
    }
  }

  return Array.from(paths).slice(0, 10);
}

function extractErrors(
  entries: SessionEntry[]
): Array<{ error: string; solution: string }> {
  const errors: Array<{ error: string; solution: string }> = [];

  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    if (entry.type !== "message") continue;

    const content = entry.message?.content || [];

    for (const block of content) {
      if (block.type === "tool_result" && block.tool_result) {
        const output = block.tool_result.output || "";
        const exitCode = block.tool_result.exitCode;

        if (exitCode && exitCode !== 0) {
          let solution = "";
          for (let j = i + 1; j < Math.min(i + 5, entries.length); j++) {
            const next = entries[j];
            if (
              next.type === "message" &&
              next.message?.role === "assistant"
            ) {
              const nextContent = next.message?.content || [];
              const thinking = extractThinkingFromContent(nextContent);
              if (thinking) {
                solution = thinking.slice(0, 200);
                break;
              }
            }
          }

          errors.push({
            error: output.slice(0, 150),
            solution: solution || "No solution recorded",
          });
        }
      }
    }
  }

  return errors.slice(0, 5);
}

function extractDecisions(entries: SessionEntry[]): string[] {
  const decisions: string[] = [];

  for (const entry of entries) {
    if (entry.type !== "message") continue;
    if (entry.message?.role !== "assistant") continue;

    const content = entry.message?.content || [];
    const thinking = extractThinkingFromContent(content);

    const decisionPatterns = [
      /(?:decided|chose|going with|instead of|rather than|picked)\s+(.{20,100})/gi,
      /(?:because|since|given that)\s+(.{20,100})/gi,
    ];

    for (const pattern of decisionPatterns) {
      let match;
      while ((match = pattern.exec(thinking)) !== null) {
        const decision = match[0].slice(0, 150);
        if (!decisions.includes(decision)) {
          decisions.push(decision);
        }
      }
    }
  }

  return decisions.slice(0, 5);
}

function extractLearnings(
  entries: SessionEntry[]
): string[] {
  const learnings: string[] = [];

  for (const entry of entries) {
    if (entry.type !== "message") continue;
    if (entry.message?.role !== "assistant") continue;

    const content = entry.message?.content || [];
    const thinking = extractThinkingFromContent(content);

    const learningPatterns = [
      /(?:learned|realized|turns out| turns out|important to note)\s+(.{20,150})/gi,
      /(?:gotcha|pitfall|watch out|be careful)\s+(.{20,150})/gi,
      /(?:note:|NB:)\s+(.{20,150})/gi,
    ];

    for (const pattern of learningPatterns) {
      let match;
      while ((match = pattern.exec(thinking)) !== null) {
        const learning = match[0].slice(0, 200);
        if (!learnings.includes(learning)) {
          learnings.push(learning);
        }
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

  const firstTimestamp = entries[0]?.timestamp
    ? new Date(entries[0].timestamp).getTime()
    : 0;
  const lastTimestamp = entries[entries.length - 1]?.timestamp
    ? new Date(entries[entries.length - 1].timestamp).getTime()
    : 0;
  const durationMs = lastTimestamp - firstTimestamp;
  const durationMin = Math.round(durationMs / 60000);
  const duration =
    durationMin < 60
      ? `${durationMin}m`
      : `${Math.floor(durationMin / 60)}h ${durationMin % 60}m`;

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
  const filesTouched = extractFilePaths(allText);

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
    for (const decision of summary.decisions) {
      lines.push(`- ${decision}`);
    }
    lines.push("");
  }

  if (summary.filesTouched.length > 0) {
    lines.push("## Files Touched");
    for (const file of summary.filesTouched) {
      lines.push(`- \`${file}\``);
    }
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
    for (const learning of summary.learnings) {
      lines.push(`- ${learning}`);
    }
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

async function appendIfNew(filePath: string, lines: string[]): Promise<boolean> {
  if (lines.length === 0) return false;
  const existing = existsSync(filePath) ? await readFile(filePath, "utf-8") : "";
  const newLines = lines.filter((l) => !existing.includes(l.trim()));
  if (newLines.length === 0) return false;
  const separator = existing.endsWith("\n\n") || existing.endsWith("\n") ? "" : existing ? "\n" : "";
  await writeFile(filePath, existing + separator + newLines.join("\n") + "\n");
  return true;
}

async function updateBrainFiles(summary: SessionSummary): Promise<void> {
  const brainDir = join(VAULT_AI, "personal");
  await mkdir(brainDir, { recursive: true });

  // Gotchas: error patterns, pitfalls, gotchas
  const gotchaLines: string[] = [];
  for (const { error, solution } of summary.errors) {
    const gotcha = `- ${error.slice(0, 100)} → ${solution.slice(0, 100)}`;
    gotchaLines.push(gotcha);
  }
  for (const learning of summary.learnings) {
    if (/gotcha|pitfall|watch out|be careful|don't|never|always|caveat/i.test(learning)) {
      gotchaLines.push(`- ${learning}`);
    }
  }
  if (gotchaLines.length > 0) {
    const gotchasFile = join(brainDir, "gotchas.md");
    if (await appendIfNew(gotchasFile, gotchaLines)) {
      console.log(`   🧠 Updated gotchas.md (+${gotchaLines.length})`);
    }
  }

  // Current: preferences, patterns, decisions
  const currentLines: string[] = [];
  for (const decision of summary.decisions) {
    if (/prefer|always use|instead of|rather than|switched to/i.test(decision)) {
      currentLines.push(`- ${decision}`);
    }
  }
  for (const learning of summary.learnings) {
    if (/prefer|pattern|convention|style|workflow/i.test(learning)) {
      currentLines.push(`- ${learning}`);
    }
  }
  if (currentLines.length > 0) {
    const currentFile = join(brainDir, "current.md");
    if (await appendIfNew(currentFile, currentLines)) {
      console.log(`   🧠 Updated current.md (+${currentLines.length})`);
    }
  }
}

// ── Logging with timestamps ────────────────────────────────────────────────

function log(msg: string): void {
  const iso = new Date().toISOString();
  console.log(`[${iso}] ${msg}`);
}

// ── Main ────────────────────────────────────────────────────────────────────

async function main() {
  const opts = parseArgs();
  const state = await loadState();
  const startTime = Date.now();
  const prevProcessedCount = Object.keys(state.processed).length;

  log("🔍 Discovering sessions...");
  const sessions = await discoverSessions(opts.since, opts.project);
  log(`   Found ${sessions.length} sessions`);
  log(`   Previously processed: ${prevProcessedCount} sessions`);

  let extracted = 0;
  let skipped = 0;
  let skipReasons: Record<string, number> = { "already processed": 0, "empty": 0 };

  for (const session of sessions) {
    if (!opts.reindex && state.processed[session.id]) {
      const processedTime = new Date(state.processed[session.id]);
      if (session.mtime <= processedTime) {
        skipReasons["already processed"]++;
        skipped++;
        continue;
      }
    }

    log(`📝 Processing: ${session.id} (${session.project})`);

    const entries = await parseSession(session.path);
    const summary = summarizeSession(entries, session.project, session.id);

    if (!summary) {
      log(`   ⚠️  Empty session, skipping`);
      skipReasons["empty"]++;
      skipped++;
      continue;
    }

    const markdown = generateMarkdown(summary);

    const dateParts = summary.date.split("-");
    const year = dateParts[0] || "unknown";
    const month = dateParts[1] || "01";
    const outDir = join(VAULT_SESSIONS_DIR, year, month);
    // Sortable filename: YYYY-MM-DD-HH-mm-ss_project_shortId.md
    const timestamp = summary.date.split(".")[0].replace(/[T:]/g, "-"); // 2026-07-28-12-52-00
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

      // Auto-update brain files (zero-token learning) with audit trail
      const brainDir = join(VAULT_AI, "personal");
      await mkdir(brainDir, { recursive: true });

      // Gotchas
      const gotchaLines: string[] = [];
      for (const { error, solution } of summary.errors) {
        const gotcha = `- ${error.slice(0, 100)} → ${solution.slice(0, 100)}`;
        gotchaLines.push(gotcha);
      }
      for (const learning of summary.learnings) {
        if (/gotcha|pitfall|watch out|be careful|don't|never|always|caveat/i.test(learning)) {
          gotchaLines.push(`- ${learning}`);
        }
      }
      if (gotchaLines.length > 0) {
        const gotchasFile = join(brainDir, "gotchas.md");
        if (await appendIfNew(gotchasFile, gotchaLines)) {
          log(`   🧠 Janitor: gotchas.md +${gotchaLines.length} (${gotchaLines.slice(0, 2).map(l => l.slice(0, 40)).join(' | ')})`);
      }
      }

      // Current
      const currentLines: string[] = [];
      for (const decision of summary.decisions) {
        if (/prefer|always use|instead of|rather than|switched to/i.test(decision)) {
          currentLines.push(`- ${decision}`);
        }
      }
      for (const learning of summary.learnings) {
        if (/prefer|pattern|convention|style|workflow/i.test(learning)) {
          currentLines.push(`- ${learning}`);
        }
      }
      if (currentLines.length > 0) {
        const currentFile = join(brainDir, "current.md");
        if (await appendIfNew(currentFile, currentLines)) {
          log(`   🧠 Janitor: current.md +${currentLines.length} (${currentLines.slice(0, 2).map(l => l.slice(0, 40)).join(' | ')})`);
        }
      }

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
  log(`   Skipped: ${skipped} (${Object.entries(skipReasons).map(([k, v]) => `${k}: ${v}`).join(", ")})`);
  log(`   Total processed state: ${prevProcessedCount} → ${newProcessedCount}`);
  log(`   Vault: ${VAULT_SESSIONS_DIR}`);
  log(`   Duration: ${(elapsedMs / 1000).toFixed(1)}s`);
}

main().catch((err) => {
  console.error("❌ Error:", err);
  process.exit(1);
});
