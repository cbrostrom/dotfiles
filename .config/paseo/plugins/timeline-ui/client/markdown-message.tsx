import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useRevealedText } from "@getpaseo/plugin/client/react-native";
import { useMemo } from "react";
import type { MarkdownMessageData } from "../shared/markdown-message.js";
import { MarkdownText } from "./markdown-text.js";
import { ProseCard } from "./prose-card.js";
import { useMessagePreferences } from "./use-message-preferences.js";

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
    <ProseCard
      values={values}
      themeBorder={theme.colors.border}
      themeSurface={theme.colors.surface1}
      compact={layout.compact}
    >
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
    </ProseCard>
  );
}
