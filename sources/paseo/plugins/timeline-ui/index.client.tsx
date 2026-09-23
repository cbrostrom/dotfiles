import type { PluginClientContext } from "@getpaseo/plugin/client";
import { AttentionMessage } from "./client/attention-message.js";
import { CallTimelineItem } from "./client/call-message.js";
import { TimelineSettings } from "./client/timeline-settings.js";
import { MarkdownMessage } from "./client/markdown-message.js";
import { ReasoningTimelineItem } from "./client/reasoning.js";
import { contributeSessionUsagePills } from "./client/session-usage-pill.js";
import { contributeThemes } from "./client/themes.js";
import { attentionMessageSchema, transformAssistantAttention } from "./shared/attention-message.js";
import { markdownMessageSchema } from "./shared/markdown-message.js";
import { peerMessageSchema } from "./shared/transform-peer-message.js";
import { transformPeerMessage } from "./shared/transform-peer-message.js";
import { transformCallMessage } from "./shared/transform-call-message.js";
import { transformToolCall } from "./shared/transform-tool-call.js";
import { transformCompaction } from "./shared/transform-compaction.js";
import { ToolCallTimelineItem } from "./client/tool-call.js";
import { CompactionTimelineItem } from "./client/compaction-line.js";
import { compactionDataSchema } from "./shared/compaction-message.js";
import {
  TOOL_RENDERER_KIND,
  TOOL_RENDERER_VERSION,
  toolItemDataSchema,
} from "./shared/tool-call.js";
import {
  CALL_RENDERER_KIND,
  CALL_RENDERER_VERSION,
  callItemDataSchema,
} from "./shared/call-message.js";
import { PeerMessage } from "./client/peer-message.js";
import {
  REASONING_RENDERER_KIND,
  REASONING_RENDERER_VERSION,
  reasoningItemDataSchema,
} from "./shared/reasoning.js";
import {
  TURN_STATUS_RENDERER_KIND,
  TURN_STATUS_RENDERER_VERSION,
  turnStatusDataSchema,
} from "./shared/turn-status.js";
import { TurnStatusTimelineItem } from "./client/turn-status.js";
import { transformReasoning } from "./shared/transform-reasoning.js";
import { PiTaskList, PiTasksPanel } from "./client/pi-tasks.js";
import { contributeClient as contributePiTasks } from "./client/pi-tasks-controller.js";
import { transformPiTodoToolCall } from "./client/transform-pi-tasks.js";
import { piTaskListSchema } from "./shared/pi-tasks.js";
import { registerSplitProbeSink, splitProbeContract } from "./shared/split-probe.js";

export default function contribute(client: PluginClientContext) {
  // TEMPORARY split-probe wire-up (remove with shared/split-probe.ts once answered).
  const removeProbe = registerSplitProbeSink((input) => {
    void client.rpc(splitProbeContract, input).catch(() => {});
  });
  const removeThemes = contributeThemes(client);
  const removeSessionUsagePills = contributeSessionUsagePills(client);

  client.addSettingsScreen({
    id: "timeline",
    title: "Timeline UI",
    icon: "MessageSquareText",
    Component: TimelineSettings,
  });

  client.addTimelineTransformer({
    id: "call-message",
    query: { itemType: "user_message" },
    transform: transformCallMessage,
  });
  client.addTimelineTransformer({
    id: "attention-blocks",
    query: { itemType: "assistant_message" },
    transform: transformAssistantAttention,
  });
  client.addTimelineTransformer({
    id: "attention-reasoning",
    query: { itemType: "reasoning" },
    transform: transformReasoning,
  });
  client.addTimelineTransformer({
    id: "peer-message",
    query: { itemType: "user_message" },
    transform: transformPeerMessage,
  });
  client.addTimelineTransformer({
    id: "tool-call",
    query: { itemType: "tool_call" },
    transform: transformToolCall,
  });
  client.addTimelineTransformer({
    id: "pi-tasks",
    query: { itemType: "tool_call" },
    transform: transformPiTodoToolCall,
  });
  client.addTimelineTransformer({
    id: "compaction-line",
    query: { itemType: "compaction" },
    transform: transformCompaction,
  });
  client.addTimelineRenderer({
    kind: "attention-message",
    version: 6,
    schema: attentionMessageSchema,
    Component: AttentionMessage,
  });
  client.addTimelineRenderer({
    kind: "markdown-message",
    version: 3,
    schema: markdownMessageSchema,
    Component: MarkdownMessage,
  });
  client.addTimelineRenderer({
    kind: "peer-message",
    version: 2,
    schema: peerMessageSchema,
    Component: PeerMessage,
  });
  client.addTimelineRenderer({
    kind: CALL_RENDERER_KIND,
    version: CALL_RENDERER_VERSION,
    schema: callItemDataSchema,
    Component: CallTimelineItem,
  });
  client.addTimelineRenderer({
    kind: TOOL_RENDERER_KIND,
    version: TOOL_RENDERER_VERSION,
    schema: toolItemDataSchema,
    Component: ToolCallTimelineItem,
  });
  client.addTimelineRenderer({
    kind: "compaction-line",
    version: 2,
    schema: compactionDataSchema,
    Component: CompactionTimelineItem,
  });
  client.addTimelineRenderer({
    kind: REASONING_RENDERER_KIND,
    version: REASONING_RENDERER_VERSION,
    schema: reasoningItemDataSchema,
    Component: ReasoningTimelineItem,
  });
  client.addTimelineRenderer({
    kind: "pi-task-list",
    version: 1,
    schema: piTaskListSchema,
    Component: PiTaskList,
  });
  client.addTimelineRenderer({
    kind: TURN_STATUS_RENDERER_KIND,
    version: TURN_STATUS_RENDERER_VERSION,
    schema: turnStatusDataSchema,
    Component: TurnStatusTimelineItem,
  });
  client.addWorkspacePanel({
    id: "pi-tasks",
    title: "Active Pi tasks",
    icon: "ListChecks",
    context: "agent",
    locations: ["workspace", "explorer"],
    Component: PiTasksPanel,
  });
  const removePiTasks = contributePiTasks(client);
  return () => {
    removeProbe();
    removeSessionUsagePills();
    removeThemes();
    removePiTasks();
  };
}
