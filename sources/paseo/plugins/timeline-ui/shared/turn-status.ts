import { z } from "zod";

/**
 * Turn-status rows: thin system rows for failed/canceled turns.
 * Appended by the server from `agent.turn_ended` lifecycle events
 * (outcome kinds "failed" and "canceled"); completed turns produce no row.
 * Auto-retry detection needs runtime evidence of per-attempt turn events;
 * intentionally not implemented yet (spec §4).
 */

export const turnStatusDataSchema = z.discriminatedUnion("kind", [
  z.object({
    kind: z.literal("failed"),
    message: z.string(),
    code: z.string().optional(),
  }),
  z.object({
    kind: z.literal("canceled"),
    reason: z.string(),
  }),
]);

export type TurnStatusData = z.output<typeof turnStatusDataSchema>;

export const TURN_STATUS_RENDERER_KIND = "turn-status";
export const TURN_STATUS_RENDERER_VERSION = 1;

/** Muted red used for failed turns; matches block-variants' error stripe. */
export const TURN_FAILED_COLOR = "#f87171";

export function turnStatusLabel(data: TurnStatusData): string {
  switch (data.kind) {
    case "failed":
      return data.code ? `Turn failed (${data.code}): ${data.message}` : `Turn failed: ${data.message}`;
    case "canceled":
      return `Canceled: ${data.reason}`;
  }
}
