import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import { Icon } from "@getpaseo/plugin/client/react-native";
import { useCallback, useMemo, useState } from "react";
import { Pressable, Text, View } from "react-native";
import type { z } from "zod";
import { buildCardChrome } from "../shared/card-display.js";
import {
  DEFAULT_TOOL_PREFERENCES,
  toolItemDataSchema,
  toolPreferences,
} from "../shared/tool-call.js";
import { MarkdownText } from "./markdown-text.js";
import { useMessagePreferences } from "./use-message-preferences.js";

type ToolData = z.output<typeof toolItemDataSchema>;

const STATUS_LABELS: Record<ToolData["status"], string | null> = {
  running: "Running",
  completed: null,
  failed: "Failed",
  canceled: "Canceled",
};

export function ToolCallTimelineItem({
  item,
  theme,
  layout,
}: PluginTimelineItemProps<ToolData>) {
  const settings = useSettings(toolPreferences);
  const preferences =
    settings.status === "ready" ? settings.values : DEFAULT_TOOL_PREFERENCES;
  const { typography } = useMessagePreferences(layout.compact);
  const [manualExpanded, setManualExpanded] = useState<boolean | null>(null);
  const expanded = manualExpanded ?? false;
  const accent = theme.colors.accent ?? theme.colors.foreground;
  const streaming = item.data.phase === "streaming";
  const stateLabel = streaming ? "Running" : STATUS_LABELS[item.data.status];

  const chrome = useMemo(
    () =>
      buildCardChrome(
        {
          borderStyle: "box",
          backgroundOpacity: 0,
          accentColor: accent,
          themeBorder: theme.colors.border,
          themeSurface: theme.colors.surface1,
        },
        layout.compact,
      ),
    [accent, layout.compact, theme.colors.border, theme.colors.surface1],
  );

  const styles = useMemo(
    () => ({
      header: {
        alignItems: "center" as const,
        flexDirection: "row" as const,
        gap: layout.compact ? 6 : 8,
        minHeight: 20,
      },
      line: {
        alignItems: "center" as const,
        flexDirection: "row" as const,
        gap: layout.compact ? 5 : 6,
        minHeight: 18,
      },
      name: {
        color: accent,
        fontSize: layout.compact ? 12 : 13,
        fontWeight: "600" as const,
      },
      summary: {
        color: theme.colors.foregroundMuted,
        flex: 1,
        fontSize: layout.compact ? 11 : 12,
      },
      state: {
        color: theme.colors.foregroundMuted,
        fontSize: layout.compact ? 11 : 12,
      },
      body: {
        color: theme.colors.foreground,
        fontSize: typography.fontSize,
        lineHeight: typography.lineHeight,
      },
    }),
    [
      accent,
      layout.compact,
      theme.colors.foreground,
      theme.colors.foregroundMuted,
      typography,
    ],
  );

  const toggle = useCallback(() => setManualExpanded(!expanded), [expanded]);

  return (
    <Pressable
      accessibilityLabel={`${expanded ? "Collapse" : "Expand"} ${item.data.name} call`}
      accessibilityRole="button"
      onPress={toggle}
    >
      {preferences.style === "inline" ? (
        <View style={[styles.line, expanded ? { alignItems: "flex-start" } : undefined]}>
          <Icon
            name={expanded ? "ChevronDown" : "ChevronRight"}
            size={11}
            color={theme.colors.foregroundMuted}
          />
          <Text style={styles.name}>{item.data.name}</Text>
          {item.data.summary ? (
            <Text style={styles.summary} numberOfLines={expanded ? undefined : 1}>
              {item.data.summary}
            </Text>
          ) : null}
          {stateLabel ? <Text style={styles.state}>{stateLabel}</Text> : null}
        </View>
      ) : (
        <View style={chrome.outer}>
          <View style={chrome.inner}>
            <View style={styles.header}>
              <Icon name={expanded ? "ChevronDown" : "ChevronRight"} size={13}
                color={theme.colors.foregroundMuted} />
              <Text style={styles.name}>{item.data.name}</Text>
              {item.data.summary ? (
                <Text style={styles.summary} numberOfLines={1} ellipsizeMode="tail">
                  {item.data.summary}
                </Text>
              ) : null}
            </View>
          </View>
        </View>
      )}
      {expanded ? (
        <MarkdownText
          text={detailToMarkdown(item.data)}
          style={styles.body}
          phase={item.data.phase}
          stableStreaming={false}
          codeBlockVariant="subtle"
          headingScale={typography.headingScale}
          stackStyle={{ gap: typography.gap }}
        />
      ) : null}
    </Pressable>
  );
}

function detailToMarkdown(data: ToolData): string {
  const items = data.items as Record<string, unknown> | null;
  if (!items) return `\`${data.name}\``;
  const command = typeof items.command === "string" ? items.command : null;
  const filePath = typeof items.filePath === "string" ? items.filePath : null;
  const output = typeof items.output === "string" ? items.output : null;
  const diff = typeof items.unifiedDiff === "string" ? items.unifiedDiff : null;
  const parts: string[] = [];
  if (filePath) parts.push(`\`${filePath}\``);
  if (command) parts.push("```\n" + command + "\n```");
  if (diff) parts.push("```diff\n" + diff + "\n```");
  else if (output) parts.push("```\n" + output + "\n```");
  if (!parts.length) return `\`${data.name}\``;
  return parts.join("\n\n");
}
