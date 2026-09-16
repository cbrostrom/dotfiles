import type { PluginTimelineTransformResult } from "@getpaseo/plugin";
import {
  COMPACTION_RENDERER_KIND,
  COMPACTION_RENDERER_VERSION,
} from "./compaction-message.js";

type CompactionItem = {
  type: "compaction";
  status: "loading" | "completed";
  trigger?: "auto" | "manual";
};

/**
 * Fold a compaction row into a renderer so the user can hide it (or keep the
 * tiny one-liner) from Timeline UI settings instead of the core block.
 */
export function transformCompaction({ item, phase }: {
  item: CompactionItem;
  phase: "streaming" | "complete";
}): PluginTimelineTransformResult {
  return {
    items: [
      {
        type: "plugin" as const,
        kind: COMPACTION_RENDERER_KIND,
        version: COMPACTION_RENDERER_VERSION,
        data: { status: item.status, trigger: item.trigger ?? "manual", phase },
      },
    ],
  };
}
