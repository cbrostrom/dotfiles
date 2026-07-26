/**
 * Working State — deterministic compaction extension
 *
 * Hooks session_before_compact, strips thinking blocks,
 * injects structured working state summary.
 * Zero token cost — no LLM calls.
 *
 * Install: symlink to ~/.pi/agent/extensions/working-state.ts
 * Reload: /reload
 */

import type { ExtensionAPI, SessionEntry } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("session_before_compact", async (event, ctx) => {
    const { preparation, customInstructions, reason } = event;

    try {
      // Access session entries to extract working state
      const entries = ctx.sessionManager.getEntries();
      if (!entries || entries.length === 0) return;

      const summary = buildWorkingState(entries, customInstructions);

      return {
        compaction: {
          summary,
          firstKeptEntryId: preparation.firstKeptEntryId,
          tokensBefore: preparation.tokensBefore,
        },
      };
    } catch {
      // Fallback to default compaction on any error
      return;
    }
  });
}

// ── Extraction helpers ──────────────────────────────────────────────────────

function extractText(entry: SessionEntry): string {
  const content = entry.message?.content || [];
  return content
    .filter((c: any) => c.type === "text" && c.text)
    .map((c: any) => c.text!)
    .join("\n");
}

function extractThinking(entry: SessionEntry): string {
  const content = entry.message?.content || [];
  return content
    .filter((c: any) => c.type === "thinking" && c.thinking)
    .map((c: any) => c.thinking!)
    .join("\n");
}

function extractToolCalls(entry: SessionEntry): Array<{ name: string; input: string }> {
  const content = entry.message?.content || [];
  return content
    .filter((c: any) => c.type === "tool_use" && c.tool_use)
    .map((c: any) => ({
      name: c.tool_use.name || "unknown",
      input: JSON.stringify(c.tool_use.input || {}).slice(0, 200),
    }));
}

function extractToolResults(entry: SessionEntry): Array<{ exitCode?: number; output: string }> {
  const content = entry.message?.content || [];
  return content
    .filter((c: any) => c.type === "tool_result" && c.tool_result)
    .map((c: any) => ({
      exitCode: c.tool_result.exitCode,
      output: (c.tool_result.output || c.tool_result.content || "").slice(0, 200),
    }));
}

// ── Working state builder ────────────────────────────────────────────────────

function buildWorkingState(entries: SessionEntry[], customInstructions?: string): string {
  const userMsgs: string[] = [];
  const assistantMsgs: string[] = [];
  const decisions: string[] = [];
  const files: Set<string> = new Set();
  const errors: string[] = [];
  const toolCalls: string[] = [];

  for (const entry of entries) {
    if (entry.type !== "message") continue;
    const role = entry.message?.role;
    const text = extractText(entry);
    const thinking = extractThinking(entry);
    const tools = extractToolCalls(entry);

    if (role === "user") {
      userMsgs.push(text);
    } else if (role === "assistant") {
      assistantMsgs.push(text);

      // Extract decisions from thinking blocks (but don't include the full thinking)
      const decisionPatterns = [
        /(?:decided|chose|going with|instead of|rather than|picked)\s+(.{20,100})/gi,
        /(?:because|since|given that)\s+(.{20,100})/gi,
        /(?:prefer|always use|switched to)\s+(.{20,100})/gi,
      ];
      for (const pattern of decisionPatterns) {
        let match;
        while ((match = pattern.exec(thinking)) !== null) {
          const d = match[0].slice(0, 150);
          if (!decisions.includes(d)) decisions.push(d);
        }
      }

      // Extract decisions from assistant text too
      const textDecisionPatterns = [
        /(?:decided|chose|going with)\s+(.{20,100})/gi,
      ];
      for (const pattern of textDecisionPatterns) {
        let match;
        while ((match = pattern.exec(text)) !== null) {
          const d = match[0].slice(0, 150);
          if (!decisions.includes(d)) decisions.push(d);
        }
      }

      // Track tool calls
      for (const t of tools) {
        if (t.name === "bash" || t.name === "read" || t.name === "edit" || t.name === "write") {
          const pathMatch = t.input.match(/["']([^"']+\.[a-z]+)["']/i);
          if (pathMatch) files.add(pathMatch[1]);
        }
        const tc = `${t.name}(${t.input.slice(0, 60)})`;
        if (!toolCalls.includes(tc)) toolCalls.push(tc);
      }
    }

    // Extract errors from tool results
    if (role === "assistant") {
      const results = extractToolResults(entry);
      for (const r of results) {
        if (r.exitCode && r.exitCode !== 0) {
          errors.push(r.output.slice(0, 150));
        }
      }
    }
  }

  // ── Build summary ──────────────────────────────────────────────────────
  const lines: string[] = [];
  lines.push("## Working State");

  // Goal from first user message
  const firstUser = userMsgs.find((m) => m.length > 10);
  if (firstUser) {
    lines.push("");
    lines.push("**Goal:** " + firstUser.slice(0, 300).replace(/\n/g, " "));
  }

  // Custom instructions (from /compact [instructions])
  if (customInstructions) {
    lines.push("");
    lines.push("**Focus:** " + customInstructions);
  }

  // Decisions
  if (decisions.length > 0) {
    lines.push("");
    lines.push("**Decisions:**");
    for (const d of decisions.slice(0, 5)) {
      lines.push("- " + d);
    }
  }

  // Files touched
  if (files.size > 0) {
    lines.push("");
    lines.push("**Files:**");
    for (const f of Array.from(files).slice(0, 8)) {
      lines.push("- `" + f + "`");
    }
  }

  // Errors
  if (errors.length > 0) {
    lines.push("");
    lines.push("**Errors:**");
    for (const e of errors.slice(0, 3)) {
      lines.push("- " + e.slice(0, 120));
    }
  }

  // Tool calls (last few)
  if (toolCalls.length > 0) {
    lines.push("");
    lines.push("**Recent activity:** " + toolCalls.slice(-4).join(", "));
  }

  // Last user message (open question / next step)
  const lastUser = userMsgs[userMsgs.length - 1];
  if (lastUser && lastUser !== firstUser) {
    const lastClean = lastUser.slice(0, 200).replace(/\n/g, " ");
    lines.push("");
    lines.push("**Next:** " + lastClean);
  }

  // Latest assistant conclusion
  const lastAssistant = assistantMsgs[assistantMsgs.length - 1];
  if (lastAssistant) {
    lines.push("");
    lines.push("**Outcome:** " + lastAssistant.slice(0, 300).replace(/\n/g, " "));
  }

  return lines.join("\n");
}
