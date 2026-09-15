import type { PluginServerContext } from "@getpaseo/plugin/server";
import { forkSettings } from "./shared/summary-fork.js";

export default function contribute(server: PluginServerContext) {
  server.registerSettings(forkSettings);
  return () => {};
}
