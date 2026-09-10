import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import { Icon, useRevealedText } from "@getpaseo/plugin/client/react-native";
import { useMemo } from "react";
import { Text, View } from "react-native";
import { buildCardChrome } from "../shared/card-display.js";
import { inferBlockIcon } from "../shared/block-icon.js";
import { blockVariant } from "../shared/block-variants.js";
import type { AttentionBlockData, AttentionMessageData } from "../shared/attention-message.js";
import {
  DEFAULT_CARD_PREFERENCES,
  parseBackgroundOpacity,
  preferences,
} from "../shared/preferences.js";
import { MarkdownText } from "./markdown-text.js";
import { useMessagePreferences } from "./use-message-preferences.js";
import { stripInlineMarkdown } from "../shared/strip-markdown.js";

const ICON_SIZE = 14;

function useCardPreferences() {
  const settings = useSettings(preferences);
  if (settings.status === "ready") return settings.values;
  return DEFAULT_CARD_PREFERENCES;
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
  const prefs = useCardPreferences();
  const { values: messagePrefs, typography } = useMessagePreferences(compact);
  const body = block.body.trim() || " ";
  const variant = blockVariant(block.title, body);
  const inferredIcon = prefs.showIcons ? inferBlockIcon(block.title, stripInlineMarkdown(body)) : null;
  const revealed = useRevealedText(body, phase);

  const chrome = useMemo(
    () =>
      buildCardChrome(
        {
          borderStyle: prefs.borderStyle,
          backgroundOpacity: parseBackgroundOpacity(prefs.backgroundOpacity),
          accentColor: variant.stripeColor,
          themeBorder: theme.colors.border,
          themeSurface: theme.colors.surface1,
        },
        compact,
      ),
    [compact, prefs.backgroundOpacity, prefs.borderStyle, theme.colors.border, theme.colors.surface1, variant.stripeColor],
  );

  const textStyles = useMemo(
    () => ({
      titleRow: {
        flexDirection: "row" as const,
        alignItems: "center" as const,
        gap: compact ? 6 : 8,
      },
      cardTitle: {
        flex: 1,
        color: theme.colors.foreground,
        fontWeight: "600" as const,
        fontSize: compact ? 13 : 14,
      },
      cardBody: {
        color: theme.colors.foregroundMuted,
        fontSize: compact ? 13 : 14,
        lineHeight: compact ? 19 : 21,
      },
    }),
    [compact, theme],
  );

  return (
    <View style={chrome.outer}>
      {chrome.stripe ? <View style={chrome.stripe} /> : null}
      {chrome.accentBar ? <View style={chrome.accentBar} /> : null}
      <View style={chrome.inner}>
        <View style={textStyles.titleRow}>
          {inferredIcon ? (
            <Icon name={inferredIcon} size={ICON_SIZE} color={variant.stripeColor} />
          ) : null}
          <Text style={textStyles.cardTitle} selectable>
            {block.title}
          </Text>
        </View>
        <MarkdownText
          text={revealed}
          style={textStyles.cardBody}
          phase={phase}
          stableStreaming={messagePrefs.stableStreaming}
          codeBlockVariant={messagePrefs.codeStyle}
          headingScale={typography.headingScale}
          stackStyle={{ gap: typography.gap }}
        />
      </View>
    </View>
  );
}
