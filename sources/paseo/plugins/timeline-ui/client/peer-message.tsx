import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import { Icon, useRevealedText } from "@getpaseo/plugin/client/react-native";
import { useMemo, useState } from "react";
import { Text, View } from "react-native";
import { buildCardChrome, hexToRgba } from "../shared/card-display.js";
import { cardAccentColor, DEFAULT_CARD_PREFERENCES, preferences } from "../shared/preferences.js";
import type { PeerMessageData } from "../shared/transform-peer-message.js";
import { MarkdownText } from "./markdown-text.js";
import { ProseCard } from "./prose-card.js";
import { useMessagePreferences } from "./use-message-preferences.js";

/** Cyan family, deliberately outside the six attention-card stripe colors. */
export const PEER_ACCENT = "#22d3ee";
const ICON_SIZE = 14;

function senderLabel(data: PeerMessageData): string {
  return data.cwd ? `pi-peer · ${data.sender} (${data.cwd})` : `pi-peer · ${data.sender}`;
}

function PeerBoundaryFooter({ data, theme }: {
  data: PeerMessageData;
  theme: PluginTimelineItemProps<PeerMessageData>["theme"];
}) {
  const [open, setOpen] = useState(false);
  if (!data.boundary && !data.replyHint) return null;
  if (!open) {
    return (
      <Text
        onPress={() => setOpen(true)}
        style={{ color: theme.colors.foregroundMuted, fontSize: 12 }}
      >
        ⓘ peer boundary
      </Text>
    );
  }
  return (
    <View style={{ gap: 4 }}>
      {data.boundary ? (
        <Text style={{ color: theme.colors.foregroundMuted, fontSize: 12, lineHeight: 17 }}>
          {data.boundary}
        </Text>
      ) : null}
      {data.replyHint ? (
        <Text style={{ color: theme.colors.foregroundMuted, fontSize: 12, lineHeight: 17 }}>
          {data.replyHint}
        </Text>
      ) : null}
      <Text
        onPress={() => setOpen(false)}
        style={{ color: theme.colors.foregroundMuted, fontSize: 12 }}
      >
        Hide
      </Text>
    </View>
  );
}

export function PeerMessage({
  item,
  theme,
  layout,
  host,
}: PluginTimelineItemProps<PeerMessageData>) {
  const data = item.data;
  const { values, typography } = useMessagePreferences(layout.compact);
  const revealed = useRevealedText(data.body, data.phase);
  const cardSettings = useSettings(preferences);
  const accent = cardAccentColor(
    cardSettings.status === "ready" ? cardSettings.values : DEFAULT_CARD_PREFERENCES,
    host?.id,
    PEER_ACCENT,
  );

  const fallbackStyle = useMemo(
    () => ({
      color: theme.colors.foreground,
      lineHeight: typography.lineHeight,
      fontSize: typography.fontSize,
    }),
    [theme.colors.foreground, typography.fontSize, typography.lineHeight],
  );

  if (!values.peerCards) {
    return (
      <ProseCard
        values={values}
        themeBorder={theme.colors.border}
        themeSurface={theme.colors.surface1}
        compact={layout.compact}
      >
        <MarkdownText
          text={data.text}
          style={fallbackStyle}
          theme={theme}
          phase={data.phase}
          stableStreaming={values.stableStreaming}
          codeBlockVariant={values.codeStyle}
          headingScale={typography.headingScale}
          stackStyle={{ gap: typography.gap }}
        />
      </ProseCard>
    );
  }

  const header = (
    <View style={{ flexDirection: "row", alignItems: "center", gap: 6 }}>
      <Icon name="MessagesSquare" size={ICON_SIZE} color={accent} />
      <Text selectable style={{ color: accent, fontSize: layout.compact ? 12 : 13, fontWeight: "600" }}>
        {senderLabel(data)}
      </Text>
    </View>
  );

  if (values.peerCardStyle === "stripe") {
    const chrome = buildCardChrome(
      {
        borderStyle: "box",
        backgroundOpacity: 0.08,
        accentColor: accent,
        themeBorder: theme.colors.border,
        themeSurface: theme.colors.surface1,
      },
      layout.compact,
    );
    return (
      <View style={{ ...chrome.outer, flexDirection: "row" }}>
        <View style={chrome.stripe!} />
        <View style={{ ...chrome.inner, gap: 6 }}>
          {header}
          <MarkdownText
            text={revealed}
            style={{ color: theme.colors.foreground, fontSize: layout.compact ? 13 : 14, lineHeight: layout.compact ? 19 : 21 }}
            theme={theme}
            phase={data.phase}
            stableStreaming={values.stableStreaming}
            codeBlockVariant={values.codeStyle}
            headingScale={typography.headingScale}
            stackStyle={{ gap: typography.gap }}
          />
          <PeerBoundaryFooter data={data} theme={theme} />
        </View>
      </View>
    );
  }

  // Bubble: offset from the left edge, rounded with a flattened top-left corner
  // so the header side reads like a speech-bubble tail.
  return (
    <View
      style={{
        alignSelf: "flex-start",
        maxWidth: "94%",
        marginLeft: 14,
        paddingHorizontal: layout.compact ? 12 : 14,
        paddingVertical: layout.compact ? 9 : 10,
        gap: 6,
        borderRadius: 16,
        borderTopLeftRadius: 5,
        borderWidth: 1,
        borderColor: hexToRgba(accent, 0.45),
        backgroundColor: hexToRgba(accent, 0.07),
      }}
    >
      {header}
      <MarkdownText
        text={revealed}
        style={{ color: theme.colors.foreground, fontSize: layout.compact ? 13 : 14, lineHeight: layout.compact ? 19 : 21 }}
        theme={theme}
        phase={data.phase}
        stableStreaming={values.stableStreaming}
        codeBlockVariant={values.codeStyle}
        headingScale={typography.headingScale}
        stackStyle={{ gap: typography.gap }}
      />
      <PeerBoundaryFooter data={data} theme={theme} />
    </View>
  );
}
