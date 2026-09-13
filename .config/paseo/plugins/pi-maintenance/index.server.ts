import type { PluginServerContext } from "@getpaseo/plugin/server";
import { handleCheckUpdates } from "./server/check-updates.js";
import { handleRunUpdates, handleUpdateProgress } from "./server/run-updates.js";
import { checkUpdates, runUpdates, updateProgress } from "./shared/updates.js";

export default function contribute(server: PluginServerContext) {
  server.handle(checkUpdates, handleCheckUpdates);
  server.handle(runUpdates, handleRunUpdates);
  server.handle(updateProgress, handleUpdateProgress);
  return () => {};
}
