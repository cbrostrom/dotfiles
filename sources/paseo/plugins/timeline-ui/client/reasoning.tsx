import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import { Icon, useRevealedText } from "@getpaseo/plugin/client/react-native";
import { useCallback, useMemo, useState, useSyncExternalStore } from "react";
import { Pressable, Text, View } from "react-native";
import type { z } from "zod";
import { buildCardChrome } from "../shared/card-display.js";
import {
  DEFAULT_REASONING_PREFERENCES,
  reasoningItemDataSchema,
  reasoningPreferences,
} from "../shared/reasoning.js";
import { MarkdownText } from "./markdown-text.js";
import { useMessagePreferences } from "./use-message-preferences.js";

const latestTimestamps = new Map<string, number>();
const listeners = new Set<() => void>();

type ReasoningData = z.output<typeof reasoningItemDataSchema>;

function publishLatest(agentId: string, timestamp: number): void {
  if (timestamp <= (latestTimestamps.get(agentId) ?? 0)) return;
  latestTimestamps.set(agentId, timestamp);
  for (const listener of listeners) listener();
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function useIsLatest(agentId: string, timestamp: Date, streaming: boolean): boolean {
  const itemTime = timestamp.getTime();
  if (streaming || itemTime > (latestTimestamps.get(agentId) ?? 0)) {
    publishLatest(agentId, itemTime);
  }
  const latest = useSyncExternalStore(
    subscribe,
    () => latestTimestamps.get(agentId) ?? 0,
    () => 0,
  );
  return streaming || (latest > 0 && itemTime >= latest);
}

export function ReasoningTimelineItem({
  agentId,
  item,
  theme,
  layout,
  timestamp,
}: PluginTimelineItemProps<ReasoningData>) {
  const settings = useSettings(reasoningPreferences);
  const preferences =
    settings.status === "ready" ? settings.values : DEFAULT_REASONING_PREFERENCES;
  const { values: messagePreferences, typography } = useMessagePreferences(layout.compact);
  const streaming = item.data.phase === "streaming";
  const latest = useIsLatest(agentId, timestamp, streaming);
  const prefersLine = preferences.mode === "line";
  const preferredExpanded =
    preferences.mode === "expanded" ||
    (preferences.mode === "expand_last" && latest && !prefersLine);
  const [manualExpanded, setManualExpanded] = useState<boolean | null>(null);
  const expanded = streaming || (manualExpanded ?? preferredExpanded);
  const revealed = useRevealedText(item.data.text, item.data.phase);
  const accent = theme.colors.foregroundMuted;

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
      title: {
        color: theme.colors.foreground,
        flex: 1,
        fontSize: layout.compact ? 13 : 14,
        fontWeight: "600" as const,
      },
      body: {
        color: theme.colors.foregroundMuted,
        fontSize: typography.fontSize,
        lineHeight: typography.lineHeight,
      },
      state: {
        color: theme.colors.foregroundMuted,
        fontSize: layout.compact ? 11 : 12,
      },
      line: {
        alignItems: "center" as const,
        flexDirection: "row" as const,
        gap: layout.compact ? 5 : 6,
        minHeight: 18,
      },
      oneLineLabel: {
        color: theme.colors.foregroundMuted,
        fontSize: layout.compact ? 12 : 13,
        fontWeight: "600" as const,
      },
      oneLinePreview: {
        color: theme.colors.foregroundMuted,
        flex: 1,
        fontSize: layout.compact ? 11 : 12,
      },
    }),
    [layout.compact, theme.colors.foreground, theme.colors.foregroundMuted, typography],
  );

  const toggle = useCallback(() => setManualExpanded(!expanded), [expanded]);

  if (prefersLine && !expanded) {
    const preview = (revealed || "").replace(/\s+/g, " ").trim().slice(0, 140);
    return (
      <Pressable
        accessibilityLabel="Expand thinking"
        accessibilityRole="button"
        onPress={toggle}
        style={[styles.line, { minHeight: 18 }]}
      >
        <Icon name="ChevronRight" size={11} color={theme.colors.foregroundMuted} />
        <Text style={styles.oneLineLabel}>Thinking</Text>
        {preview ? (
          <Text style={styles.oneLinePreview} numberOfLines={1} ellipsizeMode="tail">
            {preview}
          </Text>
        ) : null}
      </Pressable>
    );
  }

  return (
    <View style={chrome.outer}>
      <View style={chrome.inner}>
        <Pressable
          accessibilityLabel={`${expanded ? "Collapse" : "Expand"} thinking`}
          accessibilityRole="button"
          onPress={toggle}
          style={styles.header}
        >
          <Icon
            name={expanded ? "ChevronDown" : "ChevronRight"}
            size={13}
            color={theme.colors.foregroundMuted}
          />
          <Icon name="Brain" size={14} color={theme.colors.foregroundMuted} />
          <Text style={styles.title}>Thinking</Text>
          {streaming ? <Text style={styles.state}>Working</Text> : null}
        </Pressable>
        {expanded ? (
          <MarkdownText
            text={revealed}
            style={styles.body}
            phase={item.data.phase}
            stableStreaming={messagePreferences.stableStreaming}
            codeBlockVariant={messagePreferences.codeStyle}
            headingScale={typography.headingScale}
            stackStyle={{ gap: typography.gap }}
          />
        ) : null}
      </View>
    </View>
  );
}
