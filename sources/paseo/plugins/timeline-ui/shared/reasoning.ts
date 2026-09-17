import { defineSettings } from "@getpaseo/plugin";
import { z } from "zod";
import { fnv1aHash } from "./host-color.js";

export const reasoningDisplayModeSchema = z.enum([
  "collapsed",
  "expand_last",
  "expanded",
  "line",
  "hidden",
]);
export type ReasoningDisplayMode = z.output<typeof reasoningDisplayModeSchema>;

export const reasoningPreferences = defineSettings({
  id: "reasoning",
  scope: "host",
  version: 1,
  schema: z.object({
    mode: reasoningDisplayModeSchema.default("expand_last"),
    /** Rotate the "Thinking" label with deterministic, item-stable phrases. */
    rotateLabel: z.boolean().default(false),
    /** In hidden mode, show mid-answer thinking as faint one-liners instead of nothing. */
    revealHidden: z.boolean().default(false),
  }),
});

export type ReasoningPreferences = z.output<typeof reasoningPreferences.schema>;

export const DEFAULT_REASONING_PREFERENCES: ReasoningPreferences = {
  mode: "expand_last",
  rotateLabel: false,
  revealHidden: false,
};

export const reasoningItemDataSchema = z.object({
  text: z.string(),
  phase: z.enum(["streaming", "complete"]),
});

export const REASONING_RENDERER_KIND = "attention-reasoning";
export const REASONING_RENDERER_VERSION = 2;

/**
 * True when a reasoning item sits between assistant text fragments: some models
 * emit thinking mid-answer, which splits the answer into separate items and slots
 * the reasoning item in between. Detected by comparing timestamps against the
 * newest assistant-text item published via the assistant clock (assistant-clock.ts).
 */
export function isMidAnswerThinking(
  itemTime: number,
  latestAssistantTime: number,
  streaming: boolean,
): boolean {
  return !streaming && latestAssistantTime > itemTime;
}

/** Low-key streaming/thinking labels; picked by stable hash so they never flicker. */
export const THINKING_LABELS = [
  "Mulling",
  "Reasoning",
  "Weighing",
  "Turning over",
  "Pondering",
  "Sketching",
  "Ruminating",
  "Tracing",
  "Sorting",
  "Drafting",
] as const;

export function thinkingLabelFor(key: string): string {
  const hash = fnv1aHash(key);
  return THINKING_LABELS[hash % THINKING_LABELS.length];
}

export function formatThinkingText(text: string): string {
  const parts = text.split(/(```[\s\S]*?(?:```|$)|`[^`\n]+`)/g);
  return parts
    .map((part, index) => {
      if (index % 2 === 1) return part;
      return part.replace(/(\*\*[^*\s\n](?:[^*\n]*?[^*\s\n])?\*\*)\s*(?=\*\*)/g, "$1\n\n");
    })
    .join("");
}
