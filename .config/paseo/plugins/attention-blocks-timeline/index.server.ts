import type { PluginServerContext } from "@getpaseo/plugin/server";
import { messagePreferences } from "./shared/message-preferences.js";
import { preferences } from "./shared/preferences.js";
import { reasoningPreferences } from "./shared/reasoning.js";

export default function contribute(server: PluginServerContext) {
  server.registerSettings(preferences);
  server.registerSettings(messagePreferences);
  server.registerSettings(reasoningPreferences);
  return () => {};
}
