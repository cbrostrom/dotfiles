import type { PluginTimelineTransformResult } from "@getpaseo/plugin";
import {
  REASONING_RENDERER_KIND,
  REASONING_RENDERER_VERSION,
  formatThinkingText,
} from "./reasoning.js";

type ReasoningTransformInput = {
  item: { type: "reasoning"; text: string };
  phase: "streaming" | "complete";
};

export function transformReasoning({
  item,
  phase,
}: ReasoningTransformInput): PluginTimelineTransformResult {
  return {
    items: [
      {
        type: "plugin",
        kind: REASONING_RENDERER_KIND,
        version: REASONING_RENDERER_VERSION,
        data: { text: formatThinkingText(item.text), phase },
      },
    ],
  };
}
