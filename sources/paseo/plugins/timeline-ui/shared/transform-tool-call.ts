import type { PluginTimelineTransformResult } from "@getpaseo/plugin";
import {
  TOOL_RENDERER_KIND,
  TOOL_RENDERER_VERSION,
  buildToolCallData,
  isToolCall,
} from "./tool-call.js";

type TransformPhase = "streaming" | "complete";

/**
 * Fold a tool_call row into a compact timeline item (one line, expandable).
 * The renderer decides between inline and card presentation via settings.
 */
export function transformToolCall({ item, phase }: {
  item: unknown;
  phase: TransformPhase;
}): PluginTimelineTransformResult | undefined {
  if (!isToolCall(item)) return undefined;
  return {
    items: [
      {
        type: "plugin" as const,
        kind: TOOL_RENDERER_KIND,
        version: TOOL_RENDERER_VERSION,
        data: buildToolCallData(item, phase) as never,
      },
    ],
  };
}
