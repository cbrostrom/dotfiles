import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { Text, View } from "react-native";
import type { z } from "zod";
import { compactionDataSchema, compactionLabel } from "../shared/compaction-message.js";
import { useMessagePreferences } from "./use-message-preferences.js";

type CompactionData = z.output<typeof compactionDataSchema>;

export function CompactionTimelineItem({ item }: PluginTimelineItemProps<CompactionData>) {
  const { values } = useMessagePreferences(false);
  if (values.hideCompaction) return null;
  return (
    <View style={{ minHeight: 16, paddingVertical: 2 }}>
      <Text style={{ fontSize: 11, opacity: 0.6 }}>{'\u2318'} {compactionLabel(item.data)}</Text>
    </View>
  );
}
