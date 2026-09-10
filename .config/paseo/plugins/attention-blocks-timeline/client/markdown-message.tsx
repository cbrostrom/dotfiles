import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useRevealedText } from "@getpaseo/plugin/client/react-native";
import { useMemo } from "react";
import { MarkdownText } from "./markdown-text.js";
import { useMessagePreferences } from "./use-message-preferences.js";
import type { MarkdownMessageData } from "../shared/markdown-message.js";

export function MarkdownMessage({
  item,
  theme,
  layout,
}: PluginTimelineItemProps<MarkdownMessageData>) {
  const { text, phase } = item.data;
  const revealed = useRevealedText(text, phase);
  const { values, typography } = useMessagePreferences(layout.compact);
  const style = useMemo(
    () => ({
      color: theme.colors.foreground,
      lineHeight: typography.lineHeight,
      fontSize: typography.fontSize,
    }),
    [theme.colors.foreground, typography.fontSize, typography.lineHeight],
  );

  return (
    <MarkdownText
      text={revealed}
      style={style}
      phase={phase}
      stableStreaming={values.stableStreaming}
      codeBlockVariant={values.codeStyle}
      headingScale={typography.headingScale}
      stackStyle={{ gap: typography.gap }}
    />
  );
}
