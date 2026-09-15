import type { RenderedSegment, SegmentContext } from "../types.js";
import { color } from "./helpers.js";

const MAX_TOOL_CHARS = 18;

function truncateTool(name: string): string {
  if (name.length <= MAX_TOOL_CHARS) return name;
  return `${name.slice(0, MAX_TOOL_CHARS - 1)}…`;
}

export const activitySegment = {
  id: "activity" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const { state, toolName } = ctx.activity;

    if (state === "working") {
      const label = toolName ? `● ${truncateTool(toolName)}` : "● work";
      return { content: color(ctx, "activityWorking", label), visible: true };
    }

    return { content: color(ctx, "activityReady", "○ ready"), visible: true };
  },
};
