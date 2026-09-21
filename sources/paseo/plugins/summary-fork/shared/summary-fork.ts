import { defineSettings } from "@getpaseo/plugin";
import { z } from "zod";

export const forkSettings = defineSettings({
  id: "fork",
  scope: "host",
  version: 1,
  schema: z.object({
    summarizerModel: z.string().default("opencode-go/glm-5.3-flash"),
    maxTranscriptBytes: z.number().int().positive().default(120_000),
  }),
});

export type ForkSettings = z.output<typeof forkSettings.schema>;

export const DEFAULT_FORK_SETTINGS: ForkSettings = {
  summarizerModel: "opencode-go/glm-5.3-flash",
  maxTranscriptBytes: 120_000,
};

export type ForkScope = "since_compaction" | "full" | "last_10" | "last_25" | "last_50";

/** Where the forked agent lands: a new tab in the same workspace, or a new workspace. */
export type ForkTarget = "tab" | "workspace";

export const TARGET_OPTIONS = [
  { label: "New tab", value: "tab" },
  { label: "New workspace", value: "workspace" },
] as const;

export const SCOPE_OPTIONS = [
  { label: "Since last compaction", value: "since_compaction" },
  { label: "Full conversation", value: "full" },
  { label: "Last 10 turns", value: "last_10" },
  { label: "Last 25 turns", value: "last_25" },
  { label: "Last 50 turns", value: "last_50" },
] as const;

export interface TimelineEntry {
  kind: "user" | "assistant" | "summary";
  text: string;
}

type RawTimelineItem = { type: string; text?: unknown; status?: unknown; };

/** Keep only user and assistant text rows; drop tools, reasoning, notices, plugins. */
export function collectTextMessages(items: readonly RawTimelineItem[]): TimelineEntry[] {
  const entries: TimelineEntry[] = [];
  for (const item of items) {
    if (typeof item?.text !== "string") continue;
    if (item.type === "user_message") entries.push({ kind: "user", text: item.text });
    else if (item.type === "assistant_message") entries.push({ kind: "assistant", text: item.text });
  }
  return entries;
}

/** Applies the requested scope to raw timeline items (scope needs compaction rows). */
export function scopeTranscript(items: readonly RawTimelineItem[], scope: ForkScope): TimelineEntry[] {
  if (scope === "since_compaction") {
    let lastCompactionIndex = -1;
    items.forEach((item, index) => {
      if (item.type === "compaction" && item.status === "completed") lastCompactionIndex = index;
    });
    if (lastCompactionIndex < 0) return collectTextMessages(items);
    // The compaction summary IS the context of everything before it — dropping
    // it loses the whole pre-compaction history. Include it as a dedicated
    // entry, then user/assistant text after it.
    const source = items.slice(lastCompactionIndex);
    const entries: TimelineEntry[] = [];
    for (const item of source) {
      if (item.type === "compaction" && item.status === "completed" && typeof item.text === "string" && item.text.trim()) {
        entries.push({ kind: "summary", text: item.text.trim() });
      } else if ((item.type === "user_message" || item.type === "assistant_message") && typeof item.text === "string") {
        entries.push({ kind: item.type === "user_message" ? "user" : "assistant", text: item.text });
      }
    }
    return entries;
  }
  const entries = collectTextMessages(items);
  if (scope === "full") return entries;
  const count = Number(scope.replace("last_", ""));
  return entries.slice(-count);
}

/** Hard byte cap; trims oldest turns first so the newest context survives. */
export function capTranscript(
  entries: readonly TimelineEntry[],
  maxBytes: number,
): TimelineEntry[] {
  let total = 0;
  const kept: TimelineEntry[] = [];
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index]!;
    total += Buffer.byteLength(entry.text, "utf8") + 1;
    if (total > maxBytes) break;
    kept.unshift(entry);
  }
  return kept;
}

export function renderTranscript(entries: readonly TimelineEntry[]): string {
  return entries
    .map((entry) =>
      entry.kind === "user"
        ? `## User\n${entry.text}`
        : entry.kind === "assistant"
          ? `## Assistant\n${entry.text}`
          : `## Compaction summary (context of everything before it)\n${entry.text}`,
    )
    .join("\n\n");
}

export const SummarizerDocSchema = z.object({
  goal: z.string(),
  currentState: z.string(),
  decisions: z.array(z.string()).default([]),
  filesChanged: z.array(z.string()).default([]),
  evidence: z.array(z.string()).default([]),
  rejected: z.array(z.string()).default([]),
  constraints: z.array(z.string()).default([]),
  openQuestions: z.array(z.string()).default([]),
  nextAction: z.string(),
});
export type SummarizerDoc = z.output<typeof SummarizerDocSchema>;

/** JSON schema passed to the summarizer agent's `outputSchema` option. */
export const SUMMARIZER_OUTPUT_SCHEMA: Record<string, unknown> = {
  type: "object",
  properties: {
    goal: { type: "string" },
    currentState: { type: "string" },
    decisions: { type: "array", items: { type: "string" } },
    filesChanged: { type: "array", items: { type: "string" } },
    evidence: { type: "array", items: { type: "string" } },
    rejected: { type: "array", items: { type: "string" } },
    constraints: { type: "array", items: { type: "string" } },
    openQuestions: { type: "array", items: { type: "string" } },
    nextAction: { type: "string" },
  },
  required: ["goal", "currentState", "nextAction"],
  additionalProperties: false,
};

/** Parses the summarizer's final text; falls back to null for raw prose. */
export function parseSummarizerOutput(finalText: string): SummarizerDoc | null {
  const trimmed = finalText.trim();
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    const parsed = SummarizerDocSchema.parse(JSON.parse(trimmed.slice(start, end + 1)));
    return parsed;
  } catch {
    return null;
  }
}

export function renderSummary(doc: SummarizerDoc, sourceTitle: string): string {
  const bullets = (label: string, values: readonly string[]): string =>
    values.length > 0
      ? `\n# ${label}\n${values.map((value) => `- ${value}`).join("\n")}`
      : "";
  return [
    `# Fork summary — ${sourceTitle}`,
    "",
    "# Goal",
    doc.goal,
    "",
    "# Current state",
    doc.currentState,
    bullets("Decisions and rationale", doc.decisions),
    bullets("Files changed", doc.filesChanged),
    bullets("Evidence and verification", doc.evidence),
    bullets("Failed or rejected approaches", doc.rejected),
    bullets("Constraints and preferences", doc.constraints),
    bullets("Open questions and blockers", doc.openQuestions),
    "",
    "# Recommended next action",
    doc.nextAction,
  ].join("\n");
}

export function buildSummarizerPrompt(focus: string): string {
  const focusLine = focus.trim() ? `\nExtra focus: ${focus.trim()}` : "";
  return [
    "You are a one-shot handoff summarizer. Read the attached transcript excerpt",
    "and reply with ONLY the JSON handoff object matching the requested schema.",
    "Be terse and factual. Include file paths, commands, and verification evidence.",
    "Never copy secrets, tokens, or credentials from the transcript.",
    `Summarize the attached transcript into the handoff JSON schema.${focusLine}`,
  ].join("\n");
}

export const FORK_PROMPT =
  "Continue this task from a fresh fork. The attached fork summary is the full handoff. " +
  "Open with a one-line confirmation of the goal and next action, then proceed with the recommended next action.";

export const FORK_PROMPT_SAVE_DURABLE =
  `${FORK_PROMPT}\n` +
  "Additionally, during your first turn, save the durable decisions, reusable gotchas, " +
  "and open blockers from the summary to Higgins (decisions and gotchas only — never the full summary).";
