import { useSettings } from "@getpaseo/plugin/client";
import {
  DEFAULT_MESSAGE_PREFERENCES,
  messagePreferences,
  proseTypography,
  type MessagePreferences,
} from "../shared/message-preferences.js";

export function useMessagePreferences(compactLayout: boolean) {
  const settings = useSettings(messagePreferences);
  const values: MessagePreferences =
    settings.status === "ready" ? settings.values : DEFAULT_MESSAGE_PREFERENCES;
  const typography = proseTypography(values.proseDensity, compactLayout);
  return { values, typography };
}
