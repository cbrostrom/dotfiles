import { defineSettings } from "@getpaseo/plugin";
import { z } from "zod";

export const USAGE_DISPLAY_OPTIONS = [
  { label: "Cost", value: "cost" },
  { label: "Cost and tokens", value: "cost_tokens" },
] as const;

export const composerPreferences = defineSettings({
  id: "composer",
  scope: "host",
  version: 1,
  schema: z.object({
    showSessionUsage: z.boolean().default(true),
    usageDisplay: z.enum(["cost", "cost_tokens"]).default("cost"),
  }),
});

export type ComposerPreferences = z.output<typeof composerPreferences.schema>;

export const DEFAULT_COMPOSER_PREFERENCES: ComposerPreferences = {
  showSessionUsage: true,
  usageDisplay: "cost",
};
