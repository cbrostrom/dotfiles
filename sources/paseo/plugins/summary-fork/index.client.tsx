import type { PluginClientContext } from "@getpaseo/plugin/client";

import { ForkPanel } from "./client/fork-panel.js";
import { contributeForkPills } from "./client/pill.js";

export default function contribute(client: PluginClientContext) {
  const removePills = contributeForkPills(client);

  client.addWorkspacePanel({
    id: "fork",
    title: "Fork",
    icon: "GitFork",
    context: "agent",
    Component: ForkPanel,
  });
  client.addCommandCenterItem({
    id: "open-fork",
    title: "Fork with summary",
    icon: "GitFork",
    keywords: ["fork", "summary", "new chat", "handoff"],
    context: "agent",
    onSelect({ openPanel }) {
      openPanel("fork");
    },
  });

  return () => {
    removePills();
  };
}
