import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { Icon, useRevealedText } from "@getpaseo/plugin/client/react-native";
import { useMemo } from "react";
import { Text, View } from "react-native";
import type { AttentionBlockData, AttentionMessageData } from "../shared/attention-message.js";
import { hexToRgba, stripInlineMarkdown } from "../shared/strip-markdown.js";

const CARD = {
  borderRadius: 8,
  borderWidth: 1,
  stripeWidth: 3,
  iconSize: 14,
} as const;

function useBlockStyles(
  theme: PluginTimelineItemProps<AttentionMessageData>["theme"],
  compact: boolean,
  block: Pick<AttentionBlockData, "stripeColor" | "iconColor">,
) {
  const accentColor = block.stripeColor;

  return useMemo(
    () => ({
      accentColor,
      card: {
        flexDirection: "row" as const,
        alignSelf: "stretch" as const,
        overflow: "hidden" as const,
        borderWidth: CARD.borderWidth,
        borderColor: theme.colors.border,
        borderRadius: CARD.borderRadius,
        backgroundColor: theme.colors.surface1,
      } as const,
      stripe: {
        width: CARD.stripeWidth,
        backgroundColor: accentColor,
      } as const,
      cardInner: {
        flex: 1,
        gap: compact ? 4 : 6,
        paddingHorizontal: compact ? 12 : 14,
        paddingVertical: compact ? 10 : 11,
        backgroundColor: hexToRgba(accentColor, 0.06),
      } as const,
      titleRow: {
        flexDirection: "row" as const,
        alignItems: "center" as const,
        gap: compact ? 6 : 8,
      } as const,
      cardTitle: {
        flex: 1,
        color: theme.colors.foreground,
        fontWeight: "600" as const,
        fontSize: compact ? 13 : 14,
      } as const,
      cardBody: {
        color: theme.colors.foregroundMuted,
        fontSize: compact ? 13 : 14,
        lineHeight: compact ? 19 : 21,
      } as const,
    }),
    [accentColor, compact, theme],
  );
}

export function AttentionBlockCard({
  block,
  phase,
  theme,
  compact,
}: {
  block: AttentionBlockData;
  phase: AttentionMessageData["phase"];
  theme: PluginTimelineItemProps<AttentionMessageData>["theme"];
  compact: boolean;
}) {
  const styles = useBlockStyles(theme, compact, block);
  const body = stripInlineMarkdown(block.body.trim() || " ");
  const revealed = useRevealedText(body, phase);

  return (
    <View style={styles.card}>
      <View style={styles.stripe} />
      <View style={styles.cardInner}>
        <View style={styles.titleRow}>
          <Icon name={block.icon} size={CARD.iconSize} color={block.iconColor} />
          <Text style={styles.cardTitle}>{block.title}</Text>
        </View>
        <Text style={styles.cardBody}>{revealed}</Text>
      </View>
    </View>
  );
}
