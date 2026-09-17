import { z } from "zod";

export const markdownMessageSchema = z.object({
  text: z.string(),
  phase: z.enum(["streaming", "complete"]),
  /** Stream-split remnant: render as bare continuation prose, no card chrome. */
  continuation: z.boolean().optional(),
});

export type MarkdownMessageData = z.output<typeof markdownMessageSchema>;
