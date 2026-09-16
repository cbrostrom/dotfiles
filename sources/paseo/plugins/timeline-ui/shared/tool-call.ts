import { defineSettings } from "@getpaseo/plugin";
import { z } from "zod";

export type ToolStatus = "running" | "completed" | "failed" | "canceled";

export const toolStyleSchema = z.enum(["inline", "card"]);
export type ToolStyle = z.output<typeof toolStyleSchema>;

export const TOOL_STYLE_OPTIONS = [
  { label: "One-line (tiny)", value: "inline" },
  { label: "Card", value: "card" },
] as const;

export const toolPreferences = defineSettings({
  id: "tool-calls",
  scope: "host",
  version: 1,
  schema: z.object({
    style: toolStyleSchema.default("inline"),
  }),
});

export type ToolPreferences = z.output<typeof toolPreferences.schema>;

export const DEFAULT_TOOL_PREFERENCES: ToolPreferences = {
  style: "inline",
};

export const toolItemDataSchema = z.object({
  name: z.string(),
  summary: z.string().nullable(),
  items: z.record(z.string(), z.unknown()).nullable(),
  status: z.enum(["running", "completed", "failed", "canceled"]),
  phase: z.enum(["streaming", "complete"]),
});

export const TOOL_RENDERER_KIND = "tool-call";
export const TOOL_RENDERER_VERSION = 1;

type ToolDetailShape = { detail?: unknown };

/**
 * One-line summary of a tool call, mirroring pi-tiny-tools: command for shell,
 * path for file tools, query for searches, URL for fetches. Null when there is
 * nothing compact enough to show.
 */
export function summarizeToolCall(name: string, detail: unknown): string | null {
  if (detail && typeof detail === "object") {
    const d = detail as Record<string, unknown>;
    if (typeof d.command === "string" && d.command.trim()) {
      return compactLine(d.command, 96);
    }
    if (typeof d.filePath === "string" && d.filePath.trim()) {
      return compactLine(d.filePath, 120);
    }
    if (typeof d.query === "string" && d.query.trim()) {
      return compactLine(d.query, 96);
    }
    if (typeof d.url === "string" && d.url.trim()) {
      return compactLine(d.url, 120);
    }
  }
  return null;
}

function compactLine(text: string, max: number): string {
  const oneLine = text.replace(/\s+/g, " ").trim();
  if (oneLine.length <= max) return oneLine;
  return `${oneLine.slice(0, max - 1)}…`;
}

function toolStatus(status: unknown): ToolStatus {
  return status === "running" || status === "failed" || status === "canceled"
    ? status
    : "completed";
}

type ToolCallItem = {
  type: "tool_call";
  name: string;
  detail?: unknown;
  status?: unknown;
};

/** Narrower copy of the protocol tool_call shape for the transform step. */
export function isToolCall(item: unknown): item is ToolCallItem {
  return (
    typeof item === "object" &&
    item !== null &&
    (item as { type?: unknown }).type === "tool_call" &&
    typeof (item as { name?: unknown }).name === "string"
  );
}

export function buildToolCallData(item: ToolCallItem, phase: "streaming" | "complete") {
  return {
    name: item.name,
    summary: summarizeToolCall(item.name, item.detail),
    items: item.detail && typeof item.detail === "object" ? (item.detail as Record<string, unknown>) : null,
    status: toolStatus(item.status),
    phase,
  };
}
