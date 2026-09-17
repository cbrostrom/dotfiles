import type { ReactNode } from "react";
import { View } from "react-native";
import { useSettings } from "@getpaseo/plugin/client";
import { buildCardChrome } from "../shared/card-display.js";
import { cardAccentColor, DEFAULT_CARD_PREFERENCES, preferences } from "../shared/preferences.js";
import type { MessagePreferences } from "../shared/message-preferences.js";

/**
 * Neutral card chrome shared by every plain-prose fallback in the timeline so
 * unboxed text never appears next to the Thinking and attention cards.
 * Accent-free by default; with the project color accent enabled and a host id
 * supplied, the box is replaced by a left stripe in the host color.
 */
export function ProseCard({
  values,
  themeBorder,
  themeSurface,
  compact,
  hostId,
  children,
}: {
  values: Pick<MessagePreferences, "proseCards">;
  themeBorder: string;
  themeSurface: string;
  compact: boolean;
  hostId?: string;
  children: ReactNode;
}) {
  if (!values.proseCards) return <>{children}</>;
  const cards = useSettings(preferences);
  const cardPrefs = cards.status === "ready" ? cards.values : DEFAULT_CARD_PREFERENCES;
  const hostColor = cardAccentColor(cardPrefs, hostId, themeBorder);
  const accentOn = cardPrefs.hostColorAccent && Boolean(hostId);
  const chrome = buildCardChrome(
    {
      borderStyle: accentOn ? "left" : "box",
      backgroundOpacity: 0,
      accentColor: hostColor,
      themeBorder,
      themeSurface,
    },
    compact,
  );
  return (
    <View style={chrome.outer}>
      {chrome.stripe ? <View style={chrome.stripe} /> : null}
      <View style={chrome.inner}>{children}</View>
    </View>
  );
}
