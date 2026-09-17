import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import { useRevealedText } from "@getpaseo/plugin/client/react-native";
import { useMemo } from "react";
import { View } from "react-native";
import { markdownToPlainText } from "../shared/copy-block.js";
import { attentionProseToBlock, stripLeadingBareMarker } from "../shared/attention-blocks.js";
import { classifyProseShape } from "../shared/prose-shape.js";
import { DEFAULT_CARD_PREFERENCES, preferences } from "../shared/preferences.js";
import type { MarkdownMessageData } from "../shared/markdown-message.js";
import { AttentionBlockCard } from "./attention-block.js";
import { MarkdownText } from "./markdown-text.js";
import { CopyControls } from "./copy-controls.js";
import { ProseCard } from "./prose-card.js";
import { useAssistantClock } from "./use-assistant-clock.js";
import { useMessagePreferences } from "./use-message-preferences.js";

export function MarkdownMessage({
  agentId,
  item,
  theme,
  layout,
  host,
  timestamp,
}: PluginTimelineItemProps<MarkdownMessageData>) {
  useAssistantClock(agentId, timestamp);
  const { text, phase, continuation } = item.data;
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

  if (continuation && phase === "complete") {
    // Stream-split remnant: bare continuation prose, tucked tight under the
    // preceding answer card so the seam reads as one flowing answer.
    return (
      <View style={{ marginTop: layout.compact ? -4 : -6 }}>
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
      </View>
    );
  }

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

  // Completed fragments are classified by content shape: short plain one-liners and
  // single plain paragraphs render bare (a one-liner carries no copyable payload and
  // a title-less card around one paragraph is noise), `**Lead-in:**` paragraphs are
  // promoted to titled attention blocks, everything structured stays a ProseCard.
  // Streaming fragments keep the card path — shape is only stable once complete.
  if (phase === "complete" && values.proseCards) {
    const shape = classifyProseShape(repaired);
    if (shape.kind === "headline") {
      const headlineFontSize = Math.round(typography.fontSize * 1.05);
      return (
        <View style={{ paddingVertical: layout.compact ? 1 : 3, flex: 1 }}>
          <MarkdownText
            text={shape.text}
            style={{
              ...style,
              fontWeight: "600",
              fontSize: headlineFontSize,
              lineHeight: Math.round(headlineFontSize * 1.4),
            }}
            theme={theme}
            phase={phase}
            stableStreaming={values.stableStreaming}
            codeBlockVariant={values.codeStyle}
            headingScale={typography.headingScale}
          />
        </View>
      );
    }
    if (shape.kind === "leadIn") {
      return (
        <AttentionBlockCard
          block={{ title: shape.title, body: shape.body, variantIndex: 0 }}
          phase={phase}
          theme={theme}
          compact={layout.compact}
        />
      );
    }
    if (shape.kind === "plain") {
      return <MarkdownText
        text={shape.text}
        style={style}
        theme={theme}
        phase={phase}
        stableStreaming={values.stableStreaming}
        codeBlockVariant={values.codeStyle}
        headingScale={typography.headingScale}
        stackStyle={{ gap: typography.gap }}
      />;
    }
  }

  return (
    <ProseCard
      values={values}
      themeBorder={theme.colors.border}
      themeSurface={theme.colors.surface1}
      compact={layout.compact}
      hostId={host?.id}
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
