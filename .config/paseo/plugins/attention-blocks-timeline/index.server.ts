import type { PluginServerContext } from "@getpaseo/plugin/server";
import { preferences } from "./shared/preferences.js";

export default function contribute(server: PluginServerContext) {
  server.registerSettings(preferences);
  return () => {};
}
