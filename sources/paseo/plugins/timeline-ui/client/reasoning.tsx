import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import { Icon, useRevealedText } from "@getpaseo/plugin/client/react-native";
import { useCallback, useMemo, useState, useSyncExternalStore } from "react";
import { Pressable, Text, View } from "react-native";
import type { z } from "zod";
import { hexToRgba } from "../shared/card-display.js";
import { cardAccentColor } from "../shared/preferences.js";
import { preferences } from "../shared/preferences.js";
import {
  DEFAULT_REASONING_PREFERENCES,
  isMidAnswerThinking,
  reasoningItemDataSchema,
  reasoningPreferences,
  thinkingLabelFor,
} from "../shared/reasoning.js";
import {
  readLatestAssistantTimestamp,
  subscribeAssistantTimestamps,
} from "../shared/assistant-clock.js";
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
  host,
}: PluginTimelineItemProps<ReasoningData>) {
  const settings = useSettings(reasoningPreferences);
  const preferencesValues =
    settings.status === "ready" ? settings.values : DEFAULT_REASONING_PREFERENCES;
  const cardSettings = useSettings(preferences);
  const accent = cardAccentColor(
    cardSettings.status === "ready" ? cardSettings.values : { hostColorAccent: false },
    host?.id,
    theme.colors.foregroundMuted,
  );
  const { values: messagePreferences, typography } = useMessagePreferences(layout.compact);
  const streaming = item.data.phase === "streaming";
  const latest = useIsLatest(agentId, timestamp, streaming);
  // Mid-answer detection: an assistant-text fragment newer than this reasoning
  // item means the model emitted thinking between answer fragments.
  const latestAssistantTime = useSyncExternalStore(
    subscribeAssistantTimestamps,
    () => readLatestAssistantTimestamp(agentId),
    () => 0,
  );
  const midAnswer = isMidAnswerThinking(timestamp.getTime(), latestAssistantTime, streaming);
  // Strict modes: expand_last and hidden open only the newest item (streaming or
  // not) — never one sandwiched mid-answer; line and collapsed never open on
  // their own; expanded always does; hidden drops mid-answer rows entirely.
  const autoOpenTrailing =
    preferencesValues.mode === "expand_last" || preferencesValues.mode === "hidden";
  const preferredExpanded =
    preferencesValues.mode === "expanded" || (autoOpenTrailing && !midAnswer && latest);
  const [manualExpanded, setManualExpanded] = useState<boolean | null>(null);
  const expanded = manualExpanded ?? preferredExpanded;
  const revealed = useRevealedText(item.data.text, item.data.phase);
  const label = preferencesValues.rotateLabel
    ? thinkingLabelFor(`${agentId}:${timestamp.getTime()}`)
    : "Thinking";

  const muted = theme.colors.foregroundMuted;
  const styles = useMemo(
    () => ({
      header: {
        alignItems: "center" as const,
        flexDirection: "row" as const,
        gap: layout.compact ? 6 : 8,
        minHeight: 20,
      },
      label: {
        color: muted,
        fontSize: layout.compact ? 12 : 13,
        fontWeight: "600" as const,
        fontStyle: "italic" as const,
      },
      state: {
        color: muted,
        fontSize: layout.compact ? 11 : 12,
      },
      block: {
        borderLeftWidth: 2,
        borderLeftColor: hexToRgba(accent, 0.55),
        paddingLeft: layout.compact ? 8 : 10,
        gap: 3,
      },
      body: {
        color: muted,
        fontSize: typography.fontSize,
        lineHeight: typography.lineHeight,
        fontStyle: "italic" as const,
      },
      line: {
        alignItems: "center" as const,
        flexDirection: "row" as const,
        gap: layout.compact ? 5 : 6,
        minHeight: 18,
      },
      oneLineLabel: {
        color: muted,
        fontSize: layout.compact ? 12 : 13,
        fontWeight: "600" as const,
        fontStyle: "italic" as const,
      },
      oneLineState: {
        color: muted,
        fontSize: layout.compact ? 11 : 12,
        fontStyle: "italic" as const,
      },
      oneLinePreview: {
        color: muted,
        flex: 1,
        fontSize: layout.compact ? 11 : 12,
      },
    }),
    [accent, layout.compact, muted, typography],
  );

  const toggle = useCallback(() => setManualExpanded(!expanded), [expanded]);

  // Hidden mode drops mid-answer thinking entirely unless reveal is on; while it
  // still streams it shows as the normal working row, and reveal turns it into a
  // faint one-liner instead of nothing.
  if (
    preferencesValues.mode === "hidden" &&
    midAnswer &&
    !preferencesValues.revealHidden
  ) {
    return null;
  }

  // Collapsed: a faint one-line row — never a box, even while streaming.
  if (!expanded) {
    const preview = (revealed || "").replace(/\s+/g, " ").trim().slice(0, 140);
    return (
      <Pressable
        accessibilityLabel="Expand thinking"
        accessibilityRole="button"
        onPress={toggle}
        style={styles.line}
      >
        <Icon name="ChevronRight" size={11} color={muted} />
        <Text style={styles.oneLineLabel}>{label}</Text>
        {streaming ? <Text style={styles.oneLineState}>· working</Text> : null}
        {preview ? (
          <Text style={styles.oneLinePreview} numberOfLines={1} ellipsizeMode="tail">
            {preview}
          </Text>
        ) : null}
      </Pressable>
    );
  }

  // Expanded: muted italic text behind a thin accent line — no card chrome.
  return (
    <View style={styles.block}>
      <Pressable
        accessibilityLabel="Collapse thinking"
        accessibilityRole="button"
        onPress={toggle}
        style={styles.header}
      >
        <Icon name="ChevronDown" size={13} color={muted} />
        <Text style={styles.label}>{label}</Text>
        {streaming ? <Text style={styles.state}>· working</Text> : null}
      </Pressable>
      <MarkdownText
        text={revealed}
        style={styles.body}
        phase={item.data.phase}
        stableStreaming={messagePreferences.stableStreaming}
        codeBlockVariant={messagePreferences.codeStyle}
        headingScale={typography.headingScale}
        stackStyle={{ gap: typography.gap }}
      />
    </View>
  );
}
