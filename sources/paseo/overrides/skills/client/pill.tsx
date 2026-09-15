import type {
  PluginButtonRegistration,
  PluginClientContext,
  PluginComposerPillContribution,
} from "@getpaseo/plugin/client";

import { countEntries } from "./skills-query";
import { listSkills } from "../shared/skills";

/** One Skills pill per agent. Compatible with Paseo 0.8's button descriptor API. */
export function contributePills(client: PluginClientContext) {
  const pills = new Map<string, PluginButtonRegistration>();
  let stopped = false;

  function addPill(agentId: string, workspaceId: string) {
    if (pills.has(agentId)) return;
    const contribution = {
      id: "skills",
      title: "Skills",
      workspaceId,
      agentId,
      button: {
        title: "Skills",
        icon: "Sparkles",
        label: "Skills",
        behavior: {
          kind: "action",
          onPress() {
            client.openPanel("skills", { workspaceId, agentId });
          },
        },
      },
    } satisfies PluginComposerPillContribution;
    const registration = client.addComposerPill(contribution);
    pills.set(agentId, registration);

    void client
      .rpc(listSkills, { agentId })
      .then((result) => registration.update({ label: `Skills ${countEntries(result)}` }))
      .catch((error: unknown) => {
        if (!stopped) console.error("skills: could not count entries", error);
      });
  }

  function removePill(agentId: string) {
    pills.get(agentId)?.remove();
    pills.delete(agentId);
  }

  void client.paseo.agents
    .list()
    .then(({ entries }) => {
      for (const { agent } of entries) {
        if (agent.workspaceId) addPill(agent.id, agent.workspaceId);
      }
    })
    .catch((error: unknown) => {
      if (!stopped) console.error("skills: could not seed composer pills", error);
    });

  const unsubscribe = client.paseo.agents.subscribe((update) => {
    if (update.kind === "remove") {
      removePill(update.agentId);
      return;
    }
    const { id, workspaceId } = update.agent;
    if (workspaceId) addPill(id, workspaceId);
  });

  return () => {
    stopped = true;
    unsubscribe();
    for (const registration of pills.values()) registration.remove();
    pills.clear();
  };
}
