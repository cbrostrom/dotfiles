import { defineSettings } from "@getpaseo/plugin";
import { z } from "zod";

export const PROSE_DENSITY_OPTIONS = [
  { label: "Compact", value: "compact" },
  { label: "Default", value: "normal" },
  { label: "Comfortable", value: "comfortable" },
] as const;

export const CODE_STYLE_OPTIONS = [
  { label: "Subtle fill", value: "subtle" },
  { label: "Bordered", value: "bordered" },
] as const;

export const PEER_CARD_STYLE_OPTIONS = [
  { label: "Speech bubble", value: "bubble" },
  { label: "Color stripe", value: "stripe" },
] as const;

export const messagePreferences = defineSettings({
  id: "messages",
  scope: "host",
  version: 1,
  schema: z.object({
    attentionCards: z.boolean().default(true),
    proseCards: z.boolean().default(true),
    proseDensity: z.enum(["compact", "normal", "comfortable"]).default("normal"),
    codeStyle: z.enum(["subtle", "bordered"]).default("subtle"),
    stableStreaming: z.boolean().default(true),
    peerCards: z.boolean().default(true),
    peerCardStyle: z.enum(["bubble", "stripe"]).default("bubble"),
    hideCompaction: z.boolean().default(false),
  }),
});

export type MessagePreferences = z.output<typeof messagePreferences.schema>;

export const DEFAULT_MESSAGE_PREFERENCES: MessagePreferences = {
  attentionCards: true,
  proseCards: true,
  proseDensity: "normal",
  codeStyle: "subtle",
  stableStreaming: true,
  peerCards: true,
  peerCardStyle: "bubble",
  hideCompaction: false,
};

export function proseTypography(
  density: MessagePreferences["proseDensity"],
  compactLayout: boolean,
): { fontSize: number; lineHeight: number; headingScale: number; gap: number } {
  if (compactLayout || density === "compact") {
    return { fontSize: 13, lineHeight: 20, headingScale: 1.12, gap: 4 };
  }
  if (density === "comfortable") {
    return { fontSize: 15, lineHeight: 24, headingScale: 1.18, gap: 8 };
  }
  return { fontSize: 14, lineHeight: 22, headingScale: 1.16, gap: 6 };
}
