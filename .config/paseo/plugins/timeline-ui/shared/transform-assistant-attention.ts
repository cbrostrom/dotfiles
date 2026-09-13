import type { PluginTimelineItem } from "@getpaseo/plugin";
import { parseAttentionBlocks } from "./attention-blocks.js";

type AssistantMessageItem = { type: "assistant_message"; text: string };
type TransformPhase = "streaming" | "complete";

type TransformInput = {
  item: AssistantMessageItem;
  phase: TransformPhase;
};

function markdownPluginItem(text: string, phase: TransformPhase): PluginTimelineItem {
  return {
    type: "plugin",
    kind: "markdown-message",
    version: 1,
    data: { text, phase },
  };
}

export function transformAssistantAttention({ item, phase }: TransformInput) {
  const hasMarker = item.text.includes("**→");

  if (phase === "streaming" && hasMarker) {
    return { items: [markdownPluginItem(item.text, phase)] };
  }

  const parsed = phase === "complete" && hasMarker ? parseAttentionBlocks(item.text) : null;
  if (parsed) {
    let blockIndex = 0;
    return {
      items: [
        {
          type: "plugin" as const,
          kind: "attention-message",
          version: 5,
          data: {
            intro: parsed.intro,
            blocks: parsed.blocks.map((block, index) => ({
              title: block.title,
              body: block.body,
              variantIndex: index,
            })),
            outro: parsed.outro,
            segments: parsed.segments.map((segment) => {
              if (segment.kind === "prose") return segment;
              const variantIndex = blockIndex;
              blockIndex += 1;
              return {
                kind: "block" as const,
                title: segment.title,
                body: segment.body,
                variantIndex,
              };
            }),
            phase,
          },
        },
      ],
    };
  }

  return { items: [markdownPluginItem(item.text, phase)] };
}
