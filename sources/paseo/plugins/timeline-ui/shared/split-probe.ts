import { z } from "zod";
import { defineRpc } from "@getpaseo/plugin";

/**
 * TEMPORARY diagnostic probe (remove once answered): detects whether the host
 * re-runs a completed assistant item's transform — e.g. at the head→tail
 * migration when a turn finishes. The host memoizes transform results per item
 * object (WeakMap in projectPluginTimelineItems), so a re-run for the same
 * messageId means the item object was re-created, which would enable gated
 * merging of split answer fragments. Evidence is posted via RPC and appended to
 * a temp log by the server handler.
 */

export const splitProbeContract = defineRpc({
  name: "timeline-ui.split-probe",
  input: z.object({
    key: z.string(),
    firstSeenAt: z.string(),
    rerunAt: z.string(),
    note: z.string().optional(),
  }),
  output: z.object({ ok: z.literal(true) }),
});

const seenComplete = new Map<string, string>();
type ProbeSink = (input: z.output<typeof splitProbeContract["input"]>) => void;
let sink: ProbeSink | null = null;

export function registerSplitProbeSink(post: ProbeSink): () => void {
  sink = post;
  return () => {
    if (sink === post) sink = null;
  };
}

/**
 * Records a completed assistant transform call. Returns true the first time a
 * re-run of the same completed item is observed (same messageId or text hash).
 */
export function noteAssistantComplete(key: string): boolean {
  const now = new Date().toISOString();
  const first = seenComplete.get(key);
  if (first !== undefined) {
    if (sink) {
      try {
        sink({ key, firstSeenAt: first, rerunAt: now });
      } catch {
        // Diagnostics must never break rendering.
      }
    }
    return true;
  }
  if (seenComplete.size > 500) seenComplete.clear();
  seenComplete.set(key, now);
  return false;
}
