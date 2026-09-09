/** Minimal timeline stubs — @getpaseo/protocol is not importable in plugin bundles. */
export type AgentTimelineItem = {
  type: string;
  detail?: Record<string, unknown>;
  [key: string]: unknown;
};

export type ToolCallTimelineItem = AgentTimelineItem & {
  type: "tool_call";
  status: string;
  detail: { type: string; [key: string]: unknown };
};

export type AgentTaskItem = AgentTimelineItem & {
  type: "task";
  [key: string]: unknown;
};

export type AgentUsage = Record<string, unknown>;
