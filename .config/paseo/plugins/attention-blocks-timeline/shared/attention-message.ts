import type { PluginTimelineTransformerContribution } from "@getpaseo/plugin";
import { z } from "zod";
import { parseAttentionBlocks } from "./attention-blocks.js";

export const attentionBlockSchema = z.object({
  title: z.string(),
  body: z.string(),
  /** Resolved at render from index + title; stored for stable identity across reloads. */
  variantIndex: z.number().int().nonnegative(),
});

export const attentionMessageSchema = z.object({
  intro: z.string().nullable(),
  blocks: z.array(attentionBlockSchema),
  outro: z.string().nullable(),
  phase: z.enum(["streaming", "complete"]),
});

export type AttentionBlockData = z.output<typeof attentionBlockSchema>;
export type AttentionMessageData = z.output<typeof attentionMessageSchema>;

type AssistantTransformer = PluginTimelineTransformerContribution<"assistant_message">["transform"];

export const transformAssistantAttention: AssistantTransformer = ({ item, phase }) => {
  const hasMarker = item.text.includes("**→");

  if (phase === "streaming") {
    if (hasMarker) return { items: [] };
    return undefined;
  }

  const parsed = parseAttentionBlocks(item.text);
  if (!parsed) return undefined;

  return {
    items: [
      {
        type: "plugin" as const,
        kind: "attention-message",
        version: 3,
        data: {
          intro: null,
          blocks: parsed.blocks.map((block, index) => ({
            title: block.title,
            body: block.body,
            variantIndex: index,
          })),
          outro: parsed.outro,
          phase,
        },
      },
    ],
  };
};
