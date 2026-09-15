import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import { Icon } from "@getpaseo/plugin/client/react-native";
import { useCallback, useMemo, useState, useSyncExternalStore } from "react";
import { Pressable, Text, View } from "react-native";
import type { z } from "zod";
import { buildCardChrome } from "../shared/card-display.js";
import {
  DEFAULT_CALL_PREFERENCES,
  callItemDataSchema,
  callPreferences,
} from "../shared/call-message.js";
import { MarkdownText } from "./markdown-text.js";
import { useMessagePreferences } from "./use-message-preferences.js";

const latestTimestamps = new Map<string, number>();
const listeners = new Set<() => void>();

type CallData = z.output<typeof callItemDataSchema>;

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

export function CallTimelineItem({
  agentId,
  item,
  theme,
  layout,
  timestamp,
}: PluginTimelineItemProps<CallData>) {
  const settings = useSettings(callPreferences);
  const preferences =
    settings.status === "ready" ? settings.values : DEFAULT_CALL_PREFERENCES;
  const { typography } = useMessagePreferences(layout.compact);
  const streaming = item.data.phase === "streaming";
  const latest = useIsLatest(agentId, timestamp, streaming);
  const preferredExpanded =
    preferences.mode === "expanded" || (preferences.mode === "expand_last" && latest);
  const [manualExpanded, setManualExpanded] = useState<boolean | null>(null);
  const expanded = streaming || (manualExpanded ?? preferredExpanded);
  const accent = theme.colors.accent;

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
        color: theme.colors.foreground,
        fontSize: typography.fontSize,
        lineHeight: typography.lineHeight,
      },
      from: {
        color: theme.colors.foregroundMuted,
        fontSize: layout.compact ? 11 : 12,
      },
    }),
    [layout.compact, theme.colors.foreground, theme.colors.foregroundMuted, typography],
  );

  const toggle = useCallback(() => setManualExpanded(!expanded), [expanded]);

  return (
    <View style={chrome.outer}>
      <View style={chrome.inner}>
        <Pressable
          accessibilityLabel={`${expanded ? "Collapse" : "Expand"} call`}
          accessibilityRole="button"
          onPress={toggle}
          style={styles.header}
        >
          <Icon
            name={expanded ? "ChevronDown" : "ChevronRight"}
            size={13}
            color={theme.colors.foregroundMuted}
          />
          <Icon name="PhoneCall" size={14} color={accent} />
          <Text style={styles.title}>Call</Text>
          <Text style={styles.from}>from {item.data.from}</Text>
        </Pressable>
        {expanded ? (
          <MarkdownText
            text={item.data.body}
            style={styles.body}
            phase={item.data.phase}
            stableStreaming={false}
            codeBlockVariant="subtle"
            headingScale={typography.headingScale}
            stackStyle={{ gap: typography.gap }}
          />
        ) : null}
      </View>
    </View>
  );
}
