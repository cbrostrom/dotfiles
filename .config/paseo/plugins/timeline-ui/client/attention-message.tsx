import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useRevealedText } from "@getpaseo/plugin/client/react-native";
import { useMemo } from "react";
import { View } from "react-native";
import { AttentionBlockCard } from "./attention-block.js";
import { MarkdownText } from "./markdown-text.js";
import { ProseCard } from "./prose-card.js";
import { useMessagePreferences } from "./use-message-preferences.js";
import type { AttentionMessageData, AttentionSegmentData } from "../shared/attention-message.js";
import { attentionProseToBlock } from "../shared/attention-blocks.js";

function segmentsToPlainText(segments: readonly AttentionSegmentData[]): string {
  return segments
    .map((segment) =>
      segment.kind === "prose" ? segment.text : `**→ ${segment.title}.** ${segment.body}`,
    )
    .join("\n\n");
}

function Prose({
  text,
  phase,
  theme,
  compact,
  muted = false,
  values,
  typography,
}: {
  text: string;
  phase: AttentionMessageData["phase"];
  theme: PluginTimelineItemProps<AttentionMessageData>["theme"];
  compact: boolean;
  muted?: boolean;
  values: ReturnType<typeof useMessagePreferences>["values"];
  typography: ReturnType<typeof useMessagePreferences>["typography"];
}) {
  const revealed = useRevealedText(text, phase);
  const style = useMemo(
    () => ({
      color: muted ? theme.colors.foregroundMuted : theme.colors.foreground,
      lineHeight: typography.lineHeight,
      fontSize: typography.fontSize,
    }),
    [compact, muted, theme, typography.fontSize, typography.lineHeight],
  );
  return (
    <MarkdownText
      text={revealed}
      style={style}
      theme={theme}
      phase={phase}
      stableStreaming={values.stableStreaming}
      codeBlockVariant={values.codeStyle}
      headingScale={typography.headingScale}
      stackStyle={{ gap: typography.gap }}
    />
  );
}

export function AttentionMessage({
  item,
  theme,
  layout,
}: PluginTimelineItemProps<AttentionMessageData>) {
  const { segments, phase } = item.data;
  const { values, typography } = useMessagePreferences(layout.compact);
  const stackStyle = useMemo(() => ({ gap: layout.compact ? 8 : 10 }), [layout.compact]);
  // Safety net: prose segments starting with a **→ header render as cards.
  const normalized = useMemo(() => {
    const out: AttentionSegmentData[] = [];
    let blockIndex = 0;
    for (const segment of segments) {
      if (segment.kind === "block") {
        out.push(segment);
        blockIndex += 1;
        continue;
      }
      const converted = attentionProseToBlock(segment.text);
      if (!converted) {
        out.push(segment);
        continue;
      }
      out.push({ kind: "block", ...converted, variantIndex: blockIndex });
      blockIndex += 1;
    }
    return out;
  }, [segments]);

  if (!values.attentionCards) {
    const flat = segmentsToPlainText(normalized);
    return (
      <ProseCard
        values={values}
        themeBorder={theme.colors.border}
        themeSurface={theme.colors.surface1}
        compact={layout.compact}
      >
        <Prose
          text={flat}
          phase={phase}
          theme={theme}
          compact={layout.compact}
          values={values}
          typography={typography}
        />
      </ProseCard>
    );
  }

  return (
    <View style={stackStyle}>
      {normalized.map((segment, index) => {
        if (segment.kind === "prose") {
          const muted = index > 0 && index === segments.length - 1;
          return (
            <Prose
              key={`prose:${index}`}
              text={segment.text}
              phase={phase}
              theme={theme}
              compact={layout.compact}
              muted={muted && segments.some((entry) => entry.kind === "block")}
              values={values}
              typography={typography}
            />
          );
        }
        return (
          <AttentionBlockCard
            key={`block:${segment.title}:${index}`}
            block={segment}
            phase={phase}
            theme={theme}
            compact={layout.compact}
          />
        );
      })}
    </View>
  );
}
