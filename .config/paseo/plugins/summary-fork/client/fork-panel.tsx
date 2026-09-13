import type { PluginAgentPanelProps } from "@getpaseo/plugin/client";
import { usePaseo } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import { Icon } from "@getpaseo/plugin/client/react-native";
import { useCallback, useMemo, useState } from "react";
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  Text,
  TextInput,
  View,
} from "react-native";

import {
  DEFAULT_FORK_SETTINGS,
  FORK_PROMPT,
  FORK_PROMPT_SAVE_DURABLE,
  SCOPE_OPTIONS,
  SUMMARIZER_OUTPUT_SCHEMA,
  buildSummarizerPrompt,
  capTranscript,
  forkSettings,
  parseSummarizerOutput,
  renderSummary,
  renderTranscript,
  scopeTranscript,
  type ForkScope,
} from "../shared/summary-fork.js";

const FETCH_LIMIT = 200;
const MAX_PAGES = 3;
const SUMMARIZER_TIMEOUT_MS = 240_000;

type Phase =
  | { state: "idle" }
  | { state: "summarizing" }
  | { state: "ready"; summary: string }
  | { state: "creating"; summary: string }
  | { state: "error"; message: string };

interface Page {
  items: ReadonlyArray<{ type: string; text?: unknown; status?: unknown }>;
  direction?: string;
  pageInfo: { nextCursor: string | null; prevCursor: string | null; hasMore: boolean };
}

type TimelinePage = {
  items?: ReadonlyArray<{ type: string; text?: unknown; status?: unknown }>;
  direction?: string;
  pageInfo?: { nextCursor: string | null; prevCursor: string | null; hasMore: boolean };
};

export function ForkPanel({ theme, layout, workspaceId, agentId, navigation }: PluginAgentPanelProps) {
  const paseo = usePaseo();
  const settings = useSettings(forkSettings);
  const settingsValues =
    settings.status === "ready" ? settings.values : DEFAULT_FORK_SETTINGS;

  const [scope, setScope] = useState<ForkScope>("since_compaction");
  const [focus, setFocus] = useState("");
  const [saveDurable, setSaveDurable] = useState(false);
  const [summaryDraft, setSummaryDraft] = useState("");
  const [phase, setPhase] = useState<Phase>({ state: "idle" });

  const styles = useMemo(
    () => ({
      screen: {
        flex: 1,
        gap: layout.compact ? 10 : 14,
        padding: layout.compact ? 12 : 16,
        backgroundColor: theme.colors.surface0,
      },
      title: { color: theme.colors.foreground, fontSize: layout.compact ? 16 : 18, fontWeight: "600" as const },
      label: { color: theme.colors.foregroundMuted, fontSize: 12 },
      input: {
        color: theme.colors.foreground,
        borderColor: theme.colors.border,
        borderWidth: 1,
        borderRadius: 8,
        padding: 10,
        fontSize: 13,
      },
      scopeRow: { flexDirection: "row" as const, flexWrap: "wrap" as const, gap: 6 },
      scopeChip: {
        borderColor: theme.colors.border,
        borderWidth: 1,
        borderRadius: 14,
        paddingVertical: 4,
        paddingHorizontal: 10,
      },
      scopeChipActive: { backgroundColor: theme.colors.accent, borderColor: theme.colors.accent },
      scopeChipText: { color: theme.colors.foregroundMuted, fontSize: 12 },
      scopeChipTextActive: { color: theme.colors.accentForeground },
      summary: {
        color: theme.colors.foreground,
        borderColor: theme.colors.border,
        borderWidth: 1,
        borderRadius: 8,
        padding: 10,
        fontSize: 12,
        minHeight: 160,
        textAlignVertical: "top" as const,
      },
      button: {
        backgroundColor: theme.colors.accent,
        borderRadius: 8,
        paddingVertical: 10,
        alignItems: "center" as const,
      },
      buttonText: { color: theme.colors.accentForeground, fontSize: 14, fontWeight: "600" as const },
      secondaryButton: {
        borderColor: theme.colors.border,
        borderWidth: 1,
        borderRadius: 8,
        paddingVertical: 10,
        alignItems: "center" as const,
      },
      error: { color: theme.colors.statusDanger, fontSize: 12 },
      row: { flexDirection: "row" as const, alignItems: "center" as const, gap: 8 },
    }),
    [layout.compact, theme],
  );

  const fetchTranscript = useCallback(async (): Promise<string> => {
    const handle = paseo.agents.ref(agentId);
    let raw: Array<{ type: string; text?: unknown; status?: unknown }> = [];
    let direction: string | undefined;
    let cursor: string | null | undefined;
    for (let page = 0; page < MAX_PAGES; page += 1) {
      const payload: TimelinePage = await handle.timeline.refetch({
        limit: FETCH_LIMIT,
        ...(cursor ? { cursor: cursor as never } : {}),
      });
      direction = payload.direction ?? direction;
      raw = [...raw, ...(payload.items ?? [])];
      const pageInfo = payload.pageInfo;
      const next = direction === "backward" ? pageInfo?.prevCursor : pageInfo?.nextCursor;
      if (!pageInfo?.hasMore || !next) break;
      cursor = next;
    }
    // A backward fetch returns newest-first; normalize to chronological order.
    const chronological = direction === "backward" ? [...raw].reverse() : raw;
    const entries = capTranscript(
      scopeTranscript(chronological, scope),
      settingsValues.maxTranscriptBytes,
    );
    if (entries.length === 0) {
      throw new Error("No text messages found in the selected scope");
    }
    return renderTranscript(entries);
  }, [paseo, scope, settingsValues.maxTranscriptBytes]);

  const generate = useCallback(async () => {
    setPhase({ state: "summarizing" });
    try {
      const transcript = await fetchTranscript();
      const source = await paseo.agents.ref(agentId).refresh();
      const sourceTitle = source?.agent.title?.trim() || agentId.slice(0, 8);
      const cwd = source?.agent.cwd;
      if (!cwd) throw new Error("Source workspace directory is unavailable");

      const summarizer = await paseo.agents.create({
        config: { provider: `pi/${settingsValues.summarizerModel}` },
        cwd,
        title: `Fork summary · ${sourceTitle}`,
        autoArchive: true,
        outputSchema: SUMMARIZER_OUTPUT_SCHEMA,
      });
      let result;
      try {
        result = await summarizer.run(buildSummarizerPrompt(focus), {
          attachments: [
            {
              type: "text",
              mimeType: "text/plain",
              contextKind: "fork-transcript",
              title: `Transcript · ${sourceTitle}`,
              text: transcript,
            },
          ],
        });
      } finally {
        void summarizer;
      }
      if (result.status !== "idle" || !result.lastMessage) {
        throw new Error(result.error ?? "Summarizer did not return a final message");
      }
      const doc = parseSummarizerOutput(result.lastMessage);
      const summary = doc
        ? renderSummary(doc, sourceTitle)
        : `# Summary (raw)\n${result.lastMessage.trim()}`;
      setSummaryDraft(summary);
      setPhase({ state: "ready", summary });
    } catch (error) {
      setPhase({
        state: "error",
        message: error instanceof Error ? error.message : String(error),
      });
    }
  }, [agentId, fetchTranscript, focus, paseo, settingsValues.summarizerModel]);

  const createFork = useCallback(async () => {
    setPhase({ state: "summarizing" });
    try {
      const source = await paseo.agents.ref(agentId).refresh();
      const agent = source?.agent;
      const sourceTitle = agent?.title?.trim() || agentId.slice(0, 8);
      if (!agent?.model) throw new Error("Source model is unknown; cannot copy its configuration");
      if (!agent.cwd) throw new Error("Source workspace directory is unavailable");
      const fork = await paseo.agents.create({
        config: {
          provider: `${agent.provider}/${agent.model}`,
          ...(agent.currentModeId ? { modeId: agent.currentModeId } : {}),
          ...(agent.thinkingOptionId ? { thinkingOptionId: agent.thinkingOptionId } : {}),
          ...(agent.features
            ? {
                featureValues: Object.fromEntries(
                  agent.features.map((feature) => [feature.id, feature.value]),
                ),
              }
            : {}),
        },
        cwd: agent.cwd,
        title: `Fork · ${sourceTitle}`,
        prompt: saveDurable ? FORK_PROMPT_SAVE_DURABLE : FORK_PROMPT,
        attachments: [
          {
            type: "text",
            mimeType: "text/plain",
            contextKind: "fork-summary",
            title: `Fork summary · ${sourceTitle}`,
            text: summaryDraft,
          },
        ],
      });
      if (navigation) {
        navigation.openAgent({ agentId: fork.id });
      }
      setPhase({ state: "idle" });
      setSummaryDraft("");
    } catch (error) {
      setPhase({
        state: "error",
        message: error instanceof Error ? error.message : String(error),
      });
    }
  }, [agentId, navigation, paseo, saveDurable]);

  const busy = phase.state === "summarizing";

  return (
    <ScrollView contentContainerStyle={styles.screen}>
      <View style={styles.row}>
        <Icon name="GitFork" size={18} color={theme.colors.accent} />
        <Text style={styles.title}>Fork with summary</Text>
      </View>

      <Text style={styles.label}>Scope</Text>
      <View style={styles.scopeRow}>
        {SCOPE_OPTIONS.map((option) => {
          const active = option.value === scope;
          return (
            <Pressable
              key={option.value}
              accessibilityRole="button"
              onPress={() => setScope(option.value)}
              style={[styles.scopeChip, active && styles.scopeChipActive]}
            >
              <Text style={[styles.scopeChipText, active && styles.scopeChipTextActive]}>
                {option.label}
              </Text>
            </Pressable>
          );
        })}
      </View>

      <Text style={styles.label}>Focus instructions (optional)</Text>
      <TextInput
        value={focus}
        onChangeText={setFocus}
        placeholder="e.g. keep the plugin API decisions"
        placeholderTextColor={theme.colors.foregroundMuted}
        style={styles.input}
        editable={!busy}
      />

      {phase.state === "ready" || phase.state === "creating" ? (
        <>
          <Text style={styles.label}>Summary (editable)</Text>
          <TextInput
            value={summaryDraft}
            onChangeText={setSummaryDraft}
            multiline
            style={styles.summary}
            editable={phase.state === "ready"}
          />
          <Pressable
            accessibilityRole="switch"
            accessibilityState={{ checked: saveDurable }}
            onPress={() => setSaveDurable((value) => !value)}
            style={styles.row}
          >
            <Icon
              name={saveDurable ? "CheckSquare" : "Square"}
              size={16}
              color={theme.colors.foregroundMuted}
            />
            <Text style={styles.label}>Save durable decisions to Higgins</Text>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            onPress={() => void createFork()}
            disabled={busy || summaryDraft.trim().length === 0}
            style={styles.button}
          >
            <Text style={styles.buttonText}>{busy ? "Creating..." : "Create fork"}</Text>
          </Pressable>
        </>
      ) : (
        <Pressable
          accessibilityRole="button"
          onPress={() => void generate()}
          disabled={busy}
          style={styles.button}
        >
          {busy ? (
            <ActivityIndicator color={theme.colors.accentForeground} />
          ) : (
            <Text style={styles.buttonText}>Generate summary</Text>
          )}
        </Pressable>
      )}

      {phase.state === "error" ? <Text style={styles.error}>{phase.message}</Text> : null}
    </ScrollView>
  );
}
