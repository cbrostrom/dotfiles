import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useRevealedText } from "@getpaseo/plugin/client/react-native";
import { useMemo } from "react";
import { Text, View } from "react-native";
import { AttentionBlockCard } from "./attention-block.js";
import type { AttentionMessageData } from "../shared/attention-message.js";

function Prose({
  text,
  phase,
  theme,
  compact,
  muted = false,
}: {
  text: string;
  phase: AttentionMessageData["phase"];
  theme: PluginTimelineItemProps<AttentionMessageData>["theme"];
  compact: boolean;
  muted?: boolean;
}) {
  const revealed = useRevealedText(text, phase);
  const style = useMemo(
    () => ({
      color: muted ? theme.colors.foregroundMuted : theme.colors.foreground,
      lineHeight: compact ? 20 : 22,
      fontSize: compact ? 13 : 14,
    }),
    [compact, muted, theme],
  );
  return <Text style={style}>{revealed}</Text>;
}

export function AttentionMessage({
  item,
  theme,
  layout,
}: PluginTimelineItemProps<AttentionMessageData>) {
  const { intro, blocks, outro, phase } = item.data;
  const stackStyle = useMemo(() => ({ gap: layout.compact ? 8 : 10 }), [layout.compact]);

  return (
    <View style={stackStyle}>
      {intro ? <Prose text={intro} phase={phase} theme={theme} compact={layout.compact} /> : null}
      {blocks.map((block, index) => (
        <AttentionBlockCard
          key={`${block.title}:${block.stripeColor}:${index}`}
          block={block}
          phase={phase}
          theme={theme}
          compact={layout.compact}
        />
      ))}
      {outro ? (
        <Prose text={outro} phase={phase} theme={theme} compact={layout.compact} muted />
      ) : null}
    </View>
  );
}
