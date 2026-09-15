import { defineSettings } from "@getpaseo/plugin";
import { z } from "zod";

/** Exact marker prefix the calls-board (and the /call skill) prepend on delivery. */
export const CALL_MARKER_PREFIX = "[call:from=";

export const callDisplayModeSchema = z.enum(["collapsed", "expand_last", "expanded"]);
export type CallDisplayMode = z.output<typeof callDisplayModeSchema>;

export const callPreferences = defineSettings({
  id: "calls",
  scope: "host",
  version: 1,
  schema: z.object({
    mode: callDisplayModeSchema.default("expand_last"),
  }),
});

export type CallPreferences = z.output<typeof callPreferences.schema>;

export const DEFAULT_CALL_PREFERENCES: CallPreferences = {
  mode: "expand_last",
};

export const callItemDataSchema = z.object({
  from: z.string(),
  body: z.string(),
  phase: z.enum(["streaming", "complete"]),
});

export const CALL_RENDERER_KIND = "call-message";
export const CALL_RENDERER_VERSION = 1;

export interface ParsedCall {
  from: string;
  body: string;
}

/** Parse the marker line off an inbound call. Returns undefined for normal user rows. */
export function parseCall(text: string): ParsedCall | undefined {
  if (!text.startsWith(CALL_MARKER_PREFIX)) return undefined;
  const end = text.indexOf("]", CALL_MARKER_PREFIX.length);
  if (end === -1) return undefined;
  const from = text.slice(CALL_MARKER_PREFIX.length, end);
  if (!from) return undefined;
  return { from, body: text.slice(end + 1).trimStart() };
}
