import type { PluginButtonRegistration, PluginClientContext } from "@getpaseo/plugin/client";
import { PiMaintenanceScreen, PiUpdatesPopover } from "./client/status.js";
import { onUpdateCheckNeeded } from "./client/update-events.js";
import { checkUpdates, type UpdateStatus } from "./shared/updates.js";

const AGENT_PAGE_SIZE = 200;
const AGENT_SUBSCRIPTION_ID = "pi-maintenance-agents";
const REFRESH_INTERVAL_MS = 6 * 60 * 60 * 1_000;

type AgentSnapshot = {
  id: string;
  workspaceId?: string | null;
  provider: string;
  archivedAt?: string | null;
};

function isPiProvider(provider: string): boolean {
  return provider === "pi" || provider.startsWith("pi-") || provider === "omp";
}

export default function contribute(client: PluginClientContext) {
  const pills = new Map<string, PluginButtonRegistration>();
  const agents = new Map<string, AgentSnapshot>();
  let status: UpdateStatus | undefined;
  let stopped = false;

  const removePill = (agentId: string) => {
    pills.get(agentId)?.remove();
    pills.delete(agentId);
  };

  const syncPill = (agent: AgentSnapshot) => {
    removePill(agent.id);
    if (
      stopped ||
      !agent.workspaceId ||
      agent.archivedAt ||
      !isPiProvider(agent.provider) ||
      !status ||
      status.updates.length === 0
    ) return;

    pills.set(
      agent.id,
      client.addComposerPill({
        id: "pi-updates",
        workspaceId: agent.workspaceId,
        agentId: agent.id,
        button: {
          title: "Pi updates available",
          icon: "PackageOpen",
          label: `${status.updates.length} update${status.updates.length === 1 ? "" : "s"}`,
          behavior: { kind: "popover", Content: PiUpdatesPopover },
        },
      }),
    );
  };

  const publishStatus = (next: UpdateStatus) => {
    status = next;
    for (const agent of agents.values()) syncPill(agent);
  };

  client.addSettingsScreen({
    id: "pi-maintenance",
    title: "Pi maintenance",
    icon: "PackageOpen",
    Component: PiMaintenanceScreen,
  });

  client.addCommandCenterItem({
    id: "check-pi-updates",
    title: "Check Pi updates",
    icon: "PackageOpen",
    keywords: ["extensions", "packages", "upgrade"],
    context: "global",
    onSelect({ openSettings }) {
      openSettings("pi-maintenance");
    },
  });

  const refreshStatus = async (force: boolean): Promise<void> => {
    try {
      const next = await client.rpc(checkUpdates, { force });
      if (!stopped) publishStatus(next);
    } catch {
      // Keep showing the last known status; the next refresh will retry.
    }
  };

  const unsubscribe = client.paseo.agents.subscribe((update) => {
    if (update.kind === "remove") {
      agents.delete(update.agentId);
      removePill(update.agentId);
      return;
    }
    agents.set(update.agent.id, update.agent);
    syncPill(update.agent);
  });

  void client.paseo.agents
    .list({
      filter: { includeArchived: false },
      page: { limit: AGENT_PAGE_SIZE },
      subscribe: { subscriptionId: AGENT_SUBSCRIPTION_ID },
    })
    .then((result) => {
      if (stopped) return;
      for (const { agent } of result.entries) {
        agents.set(agent.id, agent);
        syncPill(agent);
      }
    })
    .catch(() => undefined);

  void refreshStatus(false);
  // Forced: the server caches for 24h, so a non-forced call would never see
  // updates that landed outside this plugin (e.g. manual `pi update`).
  const refreshTimer = setInterval(() => void refreshStatus(true), REFRESH_INTERVAL_MS);
  const removeRefreshListener = onUpdateCheckNeeded(() => void refreshStatus(true));

  return () => {
    stopped = true;
    unsubscribe();
    clearInterval(refreshTimer);
    removeRefreshListener();
    for (const pill of pills.values()) pill.remove();
    pills.clear();
    agents.clear();
  };
}
