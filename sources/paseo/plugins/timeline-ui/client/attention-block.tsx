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
  cardAccentColor,
  parseBackgroundOpacity,
  preferences,
} from "../shared/preferences.js";
import { attentionBlockMarkdown, attentionBlockPlainText } from "../shared/copy-block.js";
import { MarkdownText } from "./markdown-text.js";
import { CopyControls } from "./copy-controls.js";
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
  hostId,
}: {
  block: AttentionBlockData;
  phase: AttentionMessageData["phase"];
  theme: PluginTimelineItemProps<AttentionMessageData>["theme"];
  compact: boolean;
  hostId?: string;
}) {
  const prefs = useCardPreferences();
  const { values: messagePrefs, typography } = useMessagePreferences(compact);
  const body = block.body.trim() || " ";
  const variant = blockVariant(block.title, body);
  const inferredIcon = prefs.showIcons ? inferBlockIcon(block.title, stripInlineMarkdown(body)) : null;
  const revealed = useRevealedText(body, phase);
  const accentColor = cardAccentColor(prefs, hostId, variant.stripeColor);

  const chrome = useMemo(
    () =>
      buildCardChrome(
        {
          borderStyle: prefs.borderStyle,
          backgroundOpacity: parseBackgroundOpacity(prefs.backgroundOpacity),
          accentColor,
          themeBorder: theme.colors.border,
          themeSurface: theme.colors.surface1,
        },
        compact,
      ),
    [accentColor, compact, prefs.backgroundOpacity, prefs.borderStyle, theme.colors.border, theme.colors.surface1],
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
            <Icon name={inferredIcon} size={ICON_SIZE} color={accentColor} />
          ) : null}
          <Text style={textStyles.cardTitle} selectable>
            {block.title}
          </Text>
          <View style={{ marginLeft: "auto" }}>
            <CopyControls
              markdown={attentionBlockMarkdown(block)}
              text={attentionBlockPlainText(block)}
              initialFormat={prefs.copyFormat}
              theme={{ foreground: theme.colors.foregroundMuted, border: theme.colors.border }}
            />
          </View>
        </View>
        <MarkdownText
          text={revealed}
          style={textStyles.cardBody}
          theme={theme}
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
