import { defineSettings } from "@getpaseo/plugin";
import { z } from "zod";

export const reasoningDisplayModeSchema = z.enum(["collapsed", "expand_last", "expanded"]);
export type ReasoningDisplayMode = z.output<typeof reasoningDisplayModeSchema>;

export const reasoningPreferences = defineSettings({
  id: "reasoning",
  scope: "host",
  version: 1,
  schema: z.object({
    mode: reasoningDisplayModeSchema.default("expand_last"),
  }),
});

export type ReasoningPreferences = z.output<typeof reasoningPreferences.schema>;

export const DEFAULT_REASONING_PREFERENCES: ReasoningPreferences = {
  mode: "expand_last",
};

export const reasoningItemDataSchema = z.object({
  text: z.string(),
  phase: z.enum(["streaming", "complete"]),
});

export const REASONING_RENDERER_KIND = "attention-reasoning";
export const REASONING_RENDERER_VERSION = 1;

export function formatThinkingText(text: string): string {
  const parts = text.split(/(```[\s\S]*?(?:```|$)|`[^`\n]+`)/g);
  return parts
    .map((part, index) => {
      if (index % 2 === 1) return part;
      return part.replace(/(\*\*[^*\s\n](?:[^*\n]*?[^*\s\n])?\*\*)\s*(?=\*\*)/g, "$1\n\n");
    })
    .join("");
}
