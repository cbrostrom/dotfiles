import { z } from "zod";

export const markdownMessageSchema = z.object({
  text: z.string(),
  phase: z.enum(["streaming", "complete"]),
});

export type MarkdownMessageData = z.output<typeof markdownMessageSchema>;
