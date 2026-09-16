import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import { useRevealedText } from "@getpaseo/plugin/client/react-native";
import { useMemo } from "react";
import { View } from "react-native";
import { markdownToPlainText } from "../shared/copy-block.js";
import { attentionProseToBlock, stripLeadingBareMarker } from "../shared/attention-blocks.js";
import { DEFAULT_CARD_PREFERENCES, preferences } from "../shared/preferences.js";
import type { MarkdownMessageData } from "../shared/markdown-message.js";
import { AttentionBlockCard } from "./attention-block.js";
import { MarkdownText } from "./markdown-text.js";
import { CopyControls } from "./copy-controls.js";
import { ProseCard } from "./prose-card.js";
import { useMessagePreferences } from "./use-message-preferences.js";

export function MarkdownMessage({
  item,
  theme,
  layout,
}: PluginTimelineItemProps<MarkdownMessageData>) {
  const { text, phase } = item.data;
  const revealed = useRevealedText(text, phase);
  // Complete markdown fragments that start with a bare `**→` marker line (stream
  // split left an opener without a body) drop the stray marker before rendering.
  const repaired = useMemo(
    () => (phase === "complete" ? stripLeadingBareMarker(revealed) : revealed),
    [phase, revealed],
  );
  const { values, typography } = useMessagePreferences(layout.compact);
  // Complete markdown fragments that start with a **→ header (e.g. a reply split
  // around streamed thinking) render as attention cards instead of prose.
  const headBlock = useMemo(
    () => (phase === "complete" && values.attentionCards ? attentionProseToBlock(repaired) : null),
    [phase, repaired, values.attentionCards],
  );
  // A complete fragment whose text got emptied (dangling `**→` opener after a
  // stream split) renders as nothing rather than an empty card.
  const empty = phase === "complete" && !repaired.trim() && !headBlock;
  const cards = useSettings(preferences);
  const copyFormat =
    cards.status === "ready" ? cards.values.copyFormat : DEFAULT_CARD_PREFERENCES.copyFormat;
  const plainText = useMemo(() => markdownToPlainText(repaired), [repaired]);
  const style = useMemo(
    () => ({
      color: theme.colors.foreground,
      lineHeight: typography.lineHeight,
      fontSize: typography.fontSize,
    }),
    [theme.colors.foreground, typography.fontSize, typography.lineHeight],
  );

  if (empty) return null;

  if (headBlock) {
    return (
      <AttentionBlockCard
        block={{ title: headBlock.title, body: headBlock.body, variantIndex: 0 }}
        phase={phase}
        theme={theme}
        compact={layout.compact}
      />
    );
  }

  return (
    <ProseCard
      values={values}
      themeBorder={theme.colors.border}
      themeSurface={theme.colors.surface1}
      compact={layout.compact}
    >
      {values.proseCards ? (
        <View style={{ flexDirection: "row", justifyContent: "flex-end", marginBottom: 2 }}>
          <CopyControls
            markdown={repaired}
            text={plainText}
            initialFormat={copyFormat}
            theme={{ foreground: theme.colors.foregroundMuted, border: theme.colors.border }}
          />
        </View>
      ) : null}
      <MarkdownText
        text={repaired}
        style={style}
        theme={theme}
        phase={phase}
        stableStreaming={values.stableStreaming}
        codeBlockVariant={values.codeStyle}
        headingScale={typography.headingScale}
        stackStyle={{ gap: typography.gap }}
      />
    </ProseCard>
  );
}
