import { defineSettings } from "@getpaseo/plugin";
import { z } from "zod";
import { COPY_FORMAT_OPTIONS } from "./copy-block.js";
import { hostAccentColor } from "./host-color.js";

export const OPACITY_OPTIONS = [
  { label: "Off (surface only)", value: "0" },
  { label: "Subtle (6%)", value: "0.06" },
  { label: "Default (11%)", value: "0.11" },
  { label: "Medium (16%)", value: "0.16" },
  { label: "Strong (22%)", value: "0.22" },
] as const;

export const BORDER_STYLE_OPTIONS = [
  { label: "None", value: "none" },
  { label: "Box (all sides)", value: "box" },
  { label: "Left accent", value: "left" },
  { label: "Top accent", value: "top" },
] as const;

export const preferences = defineSettings({
  id: "cards",
  scope: "host",
  version: 1,
  schema: z.object({
    showIcons: z.boolean().default(true),
    borderStyle: z.enum(["none", "box", "left", "top"]).default("box"),
    /** Stored as string for SettingsSelect; parsed to 0–0.35 at render. */
    backgroundOpacity: z.enum(["0", "0.06", "0.11", "0.16", "0.22"]).default("0.11"),
    /** Default payload format for copy buttons on cards and code blocks. */
    copyFormat: z.enum(["markdown", "text"]).default("markdown"),
    /** Tint card accents with a stable per-host color derived from the host id. */
    hostColorAccent: z.boolean().default(false),
  }),
});

export type CardPreferences = z.output<typeof preferences.schema>;

export const DEFAULT_CARD_PREFERENCES: CardPreferences = {
  showIcons: true,
  borderStyle: "box",
  backgroundOpacity: "0.11",
  copyFormat: "markdown",
  hostColorAccent: false,
};

export { COPY_FORMAT_OPTIONS };

export function parseBackgroundOpacity(value: CardPreferences["backgroundOpacity"]): number {
  return Number.parseFloat(value);
}

/** Resolve the accent color for a host, honoring the hostColorAccent switch. */
export function cardAccentColor(
  prefs: Pick<CardPreferences, "hostColorAccent">,
  hostId: string | undefined,
  fallback: string,
): string {
  if (!prefs.hostColorAccent || !hostId) return fallback;
  return hostAccentColor(hostId);
}
