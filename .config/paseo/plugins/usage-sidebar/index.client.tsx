import type { PluginClientContext } from "@getpaseo/plugin/client";
import { UsageSurface } from "./client/usage-surface";
const SURFACE_ID = "usage";

export default function contribute(client: PluginClientContext) {

  client.addSurface(SURFACE_ID, UsageSurface);
  client.addSidebarItem({
    id: "usage",
    title: "Usage",
    icon: "Gauge",
    surface: SURFACE_ID,
  });
  client.addCommandCenterItem({
    id: "open-usage",
    title: "Open plan usage",
    icon: "Gauge",
    keywords: ["usage", "quota", "plan", "limit", "tokens"],
    context: "global",
    onSelect: (context) => {
      context.openSurface(SURFACE_ID);
    },
  });
  return () => {};
}
