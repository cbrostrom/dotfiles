import type { PluginSurfaceProps } from "@getpaseo/plugin/client";
import { View } from "react-native";
import { CardSettings } from "./card-settings.js";
import { MessageSettings } from "./message-settings.js";
import { ReasoningSettings } from "./reasoning-settings.js";

/** Combined timeline UI settings: messages + attention cards. */
export function TimelineSettings(props: PluginSurfaceProps) {
  return (
    <View style={{ gap: 24 }}>
      <MessageSettings {...props} />
      <CardSettings {...props} />
      <ReasoningSettings {...props} />
    </View>
  );
}
