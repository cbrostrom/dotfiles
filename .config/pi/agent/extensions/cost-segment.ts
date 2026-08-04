/**
 * cost-segment — powerbar segment showing only session cost
 *
 * Registers a "cost" segment. Via /extension-settings → powerbar,
 * add "cost" to left/right and remove "tokens" to show only $X.XX.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

function emitCost(pi: ExtensionAPI, ctx: ExtensionContext): void {
  let total = 0;
  for (const entry of ctx.sessionManager.getEntries()) {
    let usage: { cost: { total: number } } | undefined;
    if (entry.type === "message" && (entry.message.role === "assistant" || entry.message.role === "toolResult")) {
      usage = entry.message.usage;
    } else if ((entry.type === "branch_summary" || entry.type === "compaction") && entry.usage) {
      usage = entry.usage;
    }
    if (usage) total += usage.cost.total;
  }

  pi.events.emit("powerbar:update", {
    id: "cost",
    text: total > 0 ? `$${total.toFixed(2)}` : undefined,
    color: "dim",
  });
}

export default function (pi: ExtensionAPI): void {
  pi.on("session_start", async (_e, ctx) => {
    pi.events.emit("powerbar:register-segment", { id: "cost", label: "Cost" });
    emitCost(pi, ctx);
  });
  pi.on("tool_result",     async (_e, ctx) => emitCost(pi, ctx));
  pi.on("turn_end",        async (_e, ctx) => emitCost(pi, ctx));
  pi.on("session_compact", async (_e, ctx) => emitCost(pi, ctx));
  pi.on("session_tree",    async (_e, ctx) => emitCost(pi, ctx));
}
