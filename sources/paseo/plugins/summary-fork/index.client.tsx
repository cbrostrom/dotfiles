import type { PluginClientContext } from "@getpaseo/plugin/client";

import { ForkPanel } from "./client/fork-panel.js";
import { contributeHandoverPills, primeHandover } from "./client/pill.js";

export default function contribute(client: PluginClientContext) {
  const removePills = contributeHandoverPills(client);

  client.addWorkspacePanel({
    id: "handover",
    title: "Handover",
    icon: "GitFork",
    context: "agent",
    Component: ForkPanel,
  });
  client.addCommandCenterItem({
    id: "open-handover",
    title: "Handover",
    icon: "GitFork",
    keywords: ["handover", "handoff", "new chat", "summary"],
    context: "agent",
    onSelect({ openPanel }) {
      openPanel("handover");
    },
  });
  // '/handover <focus>' opens the same handover UI with focus prefilled. The
  // text is never sent to the agent; the panel owns generation.
  client.addSlashCommand({
    name: "handover",
    description: "Hand this agent's task to a fresh tab or workspace",
    argumentHint: "[focus]",
    context: "agent",
    async onSubmit({ args, agent, openPanel }) {
      primeHandover("tab", args.trim());
      openPanel("handover");
    },
  });

  return () => {
    removePills();
  };
}
