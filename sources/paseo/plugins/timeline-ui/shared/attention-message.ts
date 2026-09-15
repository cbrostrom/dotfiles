import { z } from "zod";

export const attentionBlockSchema = z.object({
  title: z.string(),
  body: z.string(),
  variantIndex: z.number().int().nonnegative(),
});

export const attentionSegmentSchema = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("prose"), text: z.string() }),
  z.object({
    kind: z.literal("block"),
    title: z.string(),
    body: z.string(),
    variantIndex: z.number().int().nonnegative(),
  }),
]);

export const attentionMessageSchema = z.object({
  intro: z.string().nullable(),
  blocks: z.array(attentionBlockSchema),
  outro: z.string().nullable(),
  segments: z.array(attentionSegmentSchema),
  phase: z.enum(["streaming", "complete"]),
});

export type AttentionBlockData = z.output<typeof attentionBlockSchema>;
export type AttentionSegmentData = z.output<typeof attentionSegmentSchema>;
export type AttentionMessageData = z.output<typeof attentionMessageSchema>;

export { transformAssistantAttention } from "./transform-assistant-attention.js";
