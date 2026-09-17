import { z } from "zod";

export const compactionDataSchema = z.object({
  status: z.enum(["loading", "completed"]),
  trigger: z.enum(["auto", "manual"]),
  phase: z.enum(["streaming", "complete"]),
});

export type CompactionData = z.output<typeof compactionDataSchema>;

export const COMPACTION_RENDERER_KIND = "compaction-line";
export const COMPACTION_RENDERER_VERSION = 2;

export function compactionLabel(data: CompactionData): string {
  return data.trigger === "auto" ? "Compacted (auto)" : "Compacted";
}
