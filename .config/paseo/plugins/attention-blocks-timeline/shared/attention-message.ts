import type { PluginTimelineTransformerContribution } from "@getpaseo/plugin";
import { z } from "zod";
import { parseAttentionBlocks } from "./attention-blocks.js";
import { blockVariant } from "./block-variants.js";

export const attentionBlockSchema = z.object({
  title: z.string(),
  body: z.string(),
  icon: z.string(),
  stripeColor: z.string(),
  iconColor: z.string(),
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

  // Avoid streaming churn: exploding one row into many during partial updates duplicates cards.
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
        version: 2,
        data: {
          intro: null,
          blocks: parsed.blocks.map((block, index) => {
            const variant = blockVariant(index);
            return {
              title: block.title,
              body: block.body,
              icon: variant.icon,
              stripeColor: variant.stripeColor,
              iconColor: variant.iconColor,
            };
          }),
          outro: parsed.outro,
          phase,
        },
      },
    ],
  };
};
