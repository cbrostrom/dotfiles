import type { PluginServerContext } from "@getpaseo/plugin/server";
import { handleCheckUpdates } from "./server/check-updates.js";
import { checkUpdates } from "./shared/updates.js";

export default function contribute(server: PluginServerContext) {
  server.handle(checkUpdates, handleCheckUpdates);
  return () => {};
}
