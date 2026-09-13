import type { PluginClientContext } from "@getpaseo/plugin/client";
import { AttentionMessage } from "./client/attention-message.js";
import { TimelineSettings } from "./client/timeline-settings.js";
import { MarkdownMessage } from "./client/markdown-message.js";
import { ReasoningTimelineItem } from "./client/reasoning.js";
import { contributeSessionUsagePills } from "./client/session-usage-pill.js";
import { contributeThemes } from "./client/themes.js";
import { attentionMessageSchema, transformAssistantAttention } from "./shared/attention-message.js";
import { markdownMessageSchema } from "./shared/markdown-message.js";
import {
  REASONING_RENDERER_KIND,
  REASONING_RENDERER_VERSION,
  reasoningItemDataSchema,
} from "./shared/reasoning.js";
import { transformReasoning } from "./shared/transform-reasoning.js";

export default function contribute(client: PluginClientContext) {
  const removeThemes = contributeThemes(client);
  const removeSessionUsagePills = contributeSessionUsagePills(client);

  client.addSettingsScreen({
    id: "timeline",
    title: "Timeline UI",
    icon: "MessageSquareText",
    Component: TimelineSettings,
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
  client.addTimelineRenderer({
    kind: "attention-message",
    version: 5,
    schema: attentionMessageSchema,
    Component: AttentionMessage,
  });
  client.addTimelineRenderer({
    kind: "markdown-message",
    version: 1,
    schema: markdownMessageSchema,
    Component: MarkdownMessage,
  });
  client.addTimelineRenderer({
    kind: REASONING_RENDERER_KIND,
    version: REASONING_RENDERER_VERSION,
    schema: reasoningItemDataSchema,
    Component: ReasoningTimelineItem,
  });
  return () => {
    removeSessionUsagePills();
    removeThemes();
  };
}
