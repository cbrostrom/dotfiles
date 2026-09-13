import { settingsRpc } from "@getpaseo/plugin";
import type {
  PluginButtonContentProps,
  PluginButtonRegistration,
  PluginClientContext,
  PluginComposerPillContribution,
} from "@getpaseo/plugin/client";
import { useSyncExternalStore } from "react";
import { Text, View } from "react-native";
import {
  composerPreferences,
  DEFAULT_COMPOSER_PREFERENCES,
  type ComposerPreferences,
} from "../shared/composer-preferences.js";
import {
  formatSessionUsageLabel,
  formatTokenCount,
  type SessionUsage,
} from "../shared/session-usage.js";

const usageByAgent = new Map<string, SessionUsage | null>();
const usageListeners = new Map<string, Set<() => void>>();
const preferenceListeners = new Set<(preferences: ComposerPreferences) => void>();

export function publishComposerPreferences(preferences: ComposerPreferences): void {
  for (const listener of preferenceListeners) listener(preferences);
}

function publishUsage(agentId: string, usage: SessionUsage | null): void {
  usageByAgent.set(agentId, usage);
  for (const listener of usageListeners.get(agentId) ?? []) listener();
}

function subscribeUsage(agentId: string, listener: () => void): () => void {
  const listeners = usageListeners.get(agentId) ?? new Set<() => void>();
  listeners.add(listener);
  usageListeners.set(agentId, listeners);
  return () => {
    listeners.delete(listener);
    if (listeners.size === 0) usageListeners.delete(agentId);
  };
}

function useSessionUsage(agentId: string): SessionUsage | null {
  return useSyncExternalStore(
    (listener) => subscribeUsage(agentId, listener),
    () => usageByAgent.get(agentId) ?? null,
    () => null,
  );
}

function UsageDetails(props: PluginButtonContentProps) {
  const agentId = props.context === "agent" ? props.agentId : "";
  const usage = useSessionUsage(agentId);
  const rows = [
    ["Session cost", usage?.totalCostUsd === undefined ? "—" : `$${usage.totalCostUsd.toFixed(4)}`],
    ["Input", formatTokenCount(usage?.inputTokens)],
    ["Cached", formatTokenCount(usage?.cachedInputTokens)],
    ["Output", formatTokenCount(usage?.outputTokens)],
  ] as const;
  return (
    <View style={{ gap: 8 }}>
      {rows.map(([label, value]) => (
        <View
          key={label}
          style={{ flexDirection: "row", justifyContent: "space-between", gap: 24 }}
        >
          <Text style={{ color: props.theme.colors.foregroundMuted }}>{label}</Text>
          <Text style={{ color: props.theme.colors.foreground, fontVariant: ["tabular-nums"] }}>
            {value}
          </Text>
        </View>
      ))}
    </View>
  );
}

interface TrackedAgent {
  id: string;
  workspaceId?: string | null;
  lastUsage?: SessionUsage | null;
}

export function contributeSessionUsagePills(client: PluginClientContext) {
  const registrations = new Map<string, PluginButtonRegistration>();
  const agents = new Map<string, TrackedAgent>();
  const preferenceRpc = settingsRpc(composerPreferences.id);
  let preferences = DEFAULT_COMPOSER_PREFERENCES;
  let stopped = false;

  function syncAgent(agent: TrackedAgent): void {
    agents.set(agent.id, agent);
    publishUsage(agent.id, agent.lastUsage ?? null);
    const existing = registrations.get(agent.id);
    if (!agent.workspaceId) {
      existing?.remove();
      registrations.delete(agent.id);
      return;
    }
    const label = formatSessionUsageLabel(agent.lastUsage, preferences.usageDisplay);
    if (existing) {
      existing.update({ label, visible: preferences.showSessionUsage });
      return;
    }
    const contribution = {
      id: "session-usage",
      workspaceId: agent.workspaceId,
      agentId: agent.id,
      button: {
        title: "Session usage",
        icon: "CircleDollarSign",
        label,
        visible: preferences.showSessionUsage,
        behavior: { kind: "popover", Content: UsageDetails },
      },
    } satisfies PluginComposerPillContribution;
    registrations.set(agent.id, client.addComposerPill(contribution));
  }

  function removeAgent(agentId: string): void {
    agents.delete(agentId);
    usageByAgent.delete(agentId);
    registrations.get(agentId)?.remove();
    registrations.delete(agentId);
  }

  async function loadPreferences(): Promise<void> {
    const result = await client.rpc(preferenceRpc.read, {});
    if (result.status !== "ready") return;
    const parsed = composerPreferences.schema.safeParse(result.values);
    if (!parsed.success || stopped) return;
    preferences = parsed.data;
    for (const agent of agents.values()) syncAgent(agent);
  }

  void client.paseo.agents
    .list()
    .then(({ entries }) => {
      for (const { agent } of entries) syncAgent(agent);
    })
    .catch((error: unknown) => {
      if (!stopped) console.error("timeline-ui: could not seed session usage", error);
    });

  const unsubscribeAgents = client.paseo.agents.subscribe((update) => {
    if (update.kind === "remove") removeAgent(update.agentId);
    else syncAgent(update.agent);
  });
  const applyPreferences = (next: ComposerPreferences) => {
    preferences = next;
    for (const agent of agents.values()) syncAgent(agent);
  };
  preferenceListeners.add(applyPreferences);
  void loadPreferences();

  return () => {
    stopped = true;
    unsubscribeAgents();
    preferenceListeners.delete(applyPreferences);
    for (const registration of registrations.values()) registration.remove();
    registrations.clear();
    for (const agentId of agents.keys()) usageByAgent.delete(agentId);
    agents.clear();
  };
}
