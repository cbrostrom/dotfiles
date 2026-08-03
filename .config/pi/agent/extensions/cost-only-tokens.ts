/**
 * cost-only-tokens — overrides powerbar "tokens" segment with cost only
 *
 * Replaces the verbose "↑338 ↓204k R41M W2.0M CH99.8% $23.74" with just "$23.74".
 * Emits to the same "tokens" segment after powerbar-tokens does, so it wins.
 *
 * No settings needed — just load and it works. To restore verbose mode,
 * remove this extension from packages and /reload.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

function emitCostOnly(pi: ExtensionAPI, ctx: ExtensionContext): void {
  let totalCost = 0;

  for (const entry of ctx.sessionManager.getEntries()) {
    let usage:
      | { cost: { total: number } }
      | undefined;

    if (entry.type === "message" && (entry.message.role === "assistant" || entry.message.role === "toolResult")) {
      usage = entry.message.usage;
    } else if ((entry.type === "branch_summary" || entry.type === "compaction") && entry.usage) {
      usage = entry.usage;
    }

    if (usage) {
      totalCost += usage.cost.total;
    }
  }

  if (totalCost > 0) {
    pi.events.emit("powerbar:update", {
      id: "tokens",
      text: `$${totalCost.toFixed(2)}`,
      color: "dim",
    });
  }
}

export default function (pi: ExtensionAPI): void {
  pi.on("session_start", async (_event, ctx) => emitCostOnly(pi, ctx));
  pi.on("tool_result",   async (_event, ctx) => emitCostOnly(pi, ctx));
  pi.on("turn_end",      async (_event, ctx) => emitCostOnly(pi, ctx));
  pi.on("session_compact", async (_event, ctx) => emitCostOnly(pi, ctx));
}
