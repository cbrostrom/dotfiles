import type { PluginClientContext } from "@getpaseo/plugin/client";
import { AttentionMessage } from "./client/attention-message.js";
import { contributeThemes } from "./client/themes.js";
import { attentionMessageSchema, transformAssistantAttention } from "./shared/attention-message.js";

export default function contribute(client: PluginClientContext) {
  contributeThemes(client);

  client.addTimelineTransformer({
    id: "attention-blocks",
    query: { itemType: "assistant_message" },
    transform: transformAssistantAttention,
  });
  client.addTimelineRenderer({
    kind: "attention-message",
    version: 2,
    schema: attentionMessageSchema,
    Component: AttentionMessage,
  });
  return () => {};
}
