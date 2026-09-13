import type { PluginClientContext } from "@getpaseo/plugin/client";

import { SkillsPanel } from "./client/panel";

/**
 * Dotfiles override: the upstream Skills composer pill is removed on purpose.
 * Skills stays reachable through the workspace panel and the Command Center,
 * matching where Tasks and Agent Monitor live. Host-scoped settings are
 * unaffected (index.server.ts is unchanged).
 */
export default function contribute(client: PluginClientContext) {
  client.addWorkspacePanel({
    id: "skills",
    title: "Skills",
    icon: "Sparkles",
    context: "agent",
    Component: SkillsPanel,
  });
  client.addCommandCenterItem({
    id: "open-skills",
    title: "Skills",
    icon: "Sparkles",
    keywords: ["skill", "skills", "agent skills"],
    context: "agent",
    onSelect: ({ openPanel }) => {
      openPanel("skills");
    },
  });
  return () => {};
}
