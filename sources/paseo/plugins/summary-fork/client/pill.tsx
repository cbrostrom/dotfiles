import type {
  PluginButtonRegistration,
  PluginClientContext,
  PluginComposerPillContribution,
} from "@getpaseo/plugin/client";

const RECONCILE_MS = 30_000;

/**
 * Target pre-selected by the last menu item the user clicked. The panel reads
 * this on mount; the user can still change it there. Panel and pill share one
 * client JS context, so a module variable is the only way to pass a picker
 * result through openPanel, which carries no custom props.
 */
export let pendingForkTarget: "tab" | "workspace" = "tab";

/**
 * One Fork pill per agent. Registered idempotently from the agent directory
 * and reconciled on a short interval, so the pill reappears after daemon
 * reloads or reconnects even when no agent update arrives (the owned
 * `list({ subscribe: {} })` observation is not available in the 0.8.0 SDK).
 */
export function contributeForkPills(client: PluginClientContext) {
  const pills = new Map<string, PluginButtonRegistration>();
  let stopped = false;

  function register(agentId: string, workspaceId: string) {
    if (pills.has(agentId)) return;
    const contribution = {
      id: "fork",
      workspaceId,
      agentId,
      button: {
        title: "Fork with summary",
        icon: "GitFork",
        label: "Fork",
        behavior: {
          kind: "menu",
          items: [
            {
              kind: "item",
              id: "fork-tab",
              title: "Fork in a new tab",
              icon: "GitFork",
              behavior: {
                kind: "action",
                onPress() {
                  pendingForkTarget = "tab";
                  client.openPanel("fork", { workspaceId, agentId });
                },
              },
            },
            {
              kind: "item",
              id: "fork-workspace",
              title: "Fork in a new workspace",
              icon: "GitFork",
              behavior: {
                kind: "action",
                onPress() {
                  pendingForkTarget = "workspace";
                  client.openPanel("fork", { workspaceId, agentId });
                },
              },
            },
          ],
        },
      },
    } satisfies PluginComposerPillContribution;
    try {
      pills.set(agentId, client.addComposerPill(contribution));
    } catch (error) {
      // Duplicate registration during rapid re-evaluation: the pill already
      // exists, which is fine — never let it kill the subscription.
      console.error("summary-fork: pill registration failed", error);
    }
  }

  function reconcile(entries: ReadonlyArray<{ agent: { id: string; workspaceId?: string | null } }>) {
    if (stopped) return;
    const seen = new Set<string>();
    for (const { agent } of entries) {
      seen.add(agent.id);
      if (agent.workspaceId) register(agent.id, agent.workspaceId);
    }
    for (const [agentId, pill] of pills) {
      if (!seen.has(agentId)) {
        pill.remove();
        pills.delete(agentId);
      }
    }
  }

  async function seed(): Promise<void> {
    const { entries } = await client.paseo.agents.list();
    reconcile(entries);
  }

  void seed().catch((error: unknown) => {
    if (!stopped) console.error("summary-fork: pill seed failed", error);
  });
  const reconcileTimer = setInterval(() => {
    void seed().catch(() => undefined);
  }, RECONCILE_MS);

  const unsubscribe = client.paseo.agents.subscribe((update) => {
    if (update.kind === "remove") {
      pills.get(update.agentId)?.remove();
      pills.delete(update.agentId);
      return;
    }
    const { id, workspaceId } = update.agent;
    if (workspaceId) register(id, workspaceId);
  });

  return () => {
    stopped = true;
    clearInterval(reconcileTimer);
    unsubscribe();
    for (const pill of pills.values()) pill.remove();
    pills.clear();
  };
}
