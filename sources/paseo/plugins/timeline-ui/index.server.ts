import type { PluginServerContext } from "@getpaseo/plugin/server";
import type { z } from "zod";
import os from "node:os";
import fs from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { splitProbeContract } from "./shared/split-probe.js";
import { composerPreferences } from "./shared/composer-preferences.js";
import { messagePreferences } from "./shared/message-preferences.js";
import { preferences } from "./shared/preferences.js";
import { reasoningPreferences } from "./shared/reasoning.js";
import { TURN_STATUS_RENDERER_VERSION, turnStatusDataSchema } from "./shared/turn-status.js";
import type { PluginTimelineItem } from "@getpaseo/protocol/agent-types";

export default function contribute(server: PluginServerContext) {
  server.registerSettings(preferences);
  server.registerSettings(messagePreferences);
  server.registerSettings(reasoningPreferences);
  server.registerSettings(composerPreferences);
  // TEMPORARY split-probe sink: append re-run evidence to a temp log.
  server.handle(splitProbeContract, (input) => {
    try {
      fs.appendFileSync(path.join(os.tmpdir(), "paseo-timeline-probe.log"), JSON.stringify(input) + "\n");
    } catch {
      // Diagnostics must never break the server.
    }
    return { ok: true as const };
  });
  // Turn-status rows: append a thin system row for failed/canceled turns.
  // Completed turns produce no row. Failures of the append itself must never
  // break the lifecycle hook.
  server.on("agent.turn_ended", async (event, context) => {
    if (event.outcome.kind === "completed") return;
    const data: z.output<typeof turnStatusDataSchema> =
      event.outcome.kind === "failed"
        ? event.outcome.error.code
          ? { kind: "failed", message: event.outcome.error.message, code: event.outcome.error.code }
          : { kind: "failed", message: event.outcome.error.message }
        : { kind: "canceled", reason: event.outcome.reason };
    if (!turnStatusDataSchema.safeParse(data).success) return;
    try {
      const item: Omit<PluginTimelineItem, "pluginId"> = {
        type: "plugin",
        id: randomUUID(),
        kind: "turn-status",
        version: TURN_STATUS_RENDERER_VERSION,
        data,
      };
      await context.paseo.agents.ref(event.agent.id).timeline.append(item);
    } catch {
      // Best-effort: timeline rows must never block or fail the turn lifecycle.
    }
  });
  return () => {};
}
