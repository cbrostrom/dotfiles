import { useSettings } from "@getpaseo/plugin/client";
import {
  DEFAULT_MESSAGE_PREFERENCES,
  messagePreferences,
  proseTypography,
  type MessagePreferences,
} from "../shared/message-preferences.js";

export function useMessagePreferences(compactLayout: boolean) {
  const settings = useSettings(messagePreferences);
  // Stored docs written by older plugin versions are a strict subset of the
  // current schema (e.g. they predate `peerCards`). Merging the defaults under
  // the stored values keeps every key defined without a settings migration.
  const values: MessagePreferences =
    settings.status === "ready"
      ? { ...DEFAULT_MESSAGE_PREFERENCES, ...settings.values }
      : DEFAULT_MESSAGE_PREFERENCES;
  const typography = proseTypography(values.proseDensity, compactLayout);
  return { values, typography };
}
