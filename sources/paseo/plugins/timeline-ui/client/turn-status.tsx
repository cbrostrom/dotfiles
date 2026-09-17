import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { Text, View } from "react-native";
import type { z } from "zod";
import {
  TURN_FAILED_COLOR,
  TURN_STATUS_RENDERER_KIND,
  TURN_STATUS_RENDERER_VERSION,
  turnStatusDataSchema,
  turnStatusLabel,
} from "../shared/turn-status.js";

type TurnStatusData = z.output<typeof turnStatusDataSchema>;

export function TurnStatusTimelineItem({
  item,
  theme,
}: PluginTimelineItemProps<TurnStatusData>) {
  const failed = item.data.kind === "failed";
  return (
    <View
      style={{
        minHeight: 16,
        paddingVertical: 2,
        paddingLeft: 8,
        borderLeftWidth: failed ? 2 : 0,
        borderLeftColor: TURN_FAILED_COLOR,
      }}
    >
      <Text style={{ fontSize: 11, color: failed ? TURN_FAILED_COLOR : theme.colors.foregroundMuted }}>
        {turnStatusLabel(item.data)}
      </Text>
    </View>
  );
}

export { TURN_STATUS_RENDERER_KIND, TURN_STATUS_RENDERER_VERSION };
