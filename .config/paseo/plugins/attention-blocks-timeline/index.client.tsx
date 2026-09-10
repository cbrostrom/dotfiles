import type { PluginClientContext } from "@getpaseo/plugin/client";
import { AttentionMessage } from "./client/attention-message.js";
import { CardSettings } from "./client/card-settings.js";
import { contributeThemes } from "./client/themes.js";
import { attentionMessageSchema, transformAssistantAttention } from "./shared/attention-message.js";

export default function contribute(client: PluginClientContext) {
  contributeThemes(client);

  client.addSettingsScreen({
    id: "cards",
    title: "Attention cards",
    icon: "LayoutList",
    Component: CardSettings,
  });

  client.addTimelineTransformer({
    id: "attention-blocks",
    query: { itemType: "assistant_message" },
    transform: transformAssistantAttention,
  });
  client.addTimelineRenderer({
    kind: "attention-message",
    version: 3,
    schema: attentionMessageSchema,
    Component: AttentionMessage,
  });
  return () => {};
}
