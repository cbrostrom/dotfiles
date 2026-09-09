import type { PluginClientContext } from "@getpaseo/plugin/client";
import { WorkspaceSubagentsPanel } from "./client/agents/panel";
import { WorkspaceTasksPanel } from "./client/tasks/panel";

export default function contribute(client: PluginClientContext) {
  client.addWorkspacePanel({
    id: "tasks",
    title: "Tasks",
    icon: "ListTodo",
    context: "workspace",
    locations: ["workspace", "explorer"],
    Component: WorkspaceTasksPanel,
  });
  client.addWorkspacePanel({
    id: "agent-monitor",
    title: "Agent Monitor",
    icon: "Bot",
    context: "workspace",
    locations: ["workspace", "explorer"],
    Component: WorkspaceSubagentsPanel,
  });
  client.addWorkspacePanel({
    id: "subagents",
    title: "Agent Monitor",
    icon: "Bot",
    context: "workspace",
    locations: ["workspace", "explorer"],
    Component: WorkspaceSubagentsPanel,
  });

  client.addCommandCenterItem({
    id: "open-tasks-explorer",
    title: "Open tasks in Explorer",
    icon: "ListTodo",
    keywords: ["tasks", "todo", "explorer", "activity", "workspace"],
    context: "workspace",
    onSelect({ openPanel }) {
      openPanel("tasks", { location: "explorer" });
    },
  });
  client.addCommandCenterItem({
    id: "open-agent-monitor-explorer",
    title: "Open Agent Monitor in Explorer",
    icon: "Bot",
    keywords: [
      "agent monitor",
      "monitor",
      "subagents",
      "agents",
      "explorer",
      "activity",
      "workspace",
    ],
    context: "workspace",
    onSelect({ openPanel }) {
      openPanel("agent-monitor", { location: "explorer" });
    },
  });
  client.addCommandCenterItem({
    id: "open-tasks",
    title: "Open tasks",
    icon: "ListTodo",
    keywords: ["tasks", "todo", "activity", "workspace"],
    context: "workspace",
    onSelect({ openPanel }) {
      openPanel("tasks");
    },
  });
  client.addCommandCenterItem({
    id: "open-agent-monitor",
    title: "Open Agent Monitor",
    icon: "Bot",
    keywords: ["agent monitor", "monitor", "subagents", "agents", "activity", "workspace"],
    context: "workspace",
    onSelect({ openPanel }) {
      openPanel("agent-monitor");
    },
  });

  client.addSlashCommand({
    name: "tasks",
    description: "Open workspace Tasks panel",
    argumentHint: "",
    context: "workspace",
    onSubmit({ openPanel }) {
      openPanel("tasks");
    },
  });
  client.addSlashCommand({
    name: "agents",
    description: "Open Agent Monitor panel",
    argumentHint: "",
    context: "workspace",
    onSubmit({ openPanel }) {
      openPanel("agent-monitor");
    },
  });

  return () => {};
}
