import type { ReactNode } from "react";
import { View } from "react-native";
import { buildCardChrome } from "../shared/card-display.js";
import type { MessagePreferences } from "../shared/message-preferences.js";

/**
 * Neutral card chrome shared by every plain-prose fallback in the timeline so
 * unboxed text never appears next to the Thinking and attention cards.
 * No accent color: border + surface only.
 */
export function ProseCard({
  values,
  themeBorder,
  themeSurface,
  compact,
  children,
}: {
  values: Pick<MessagePreferences, "proseCards">;
  themeBorder: string;
  themeSurface: string;
  compact: boolean;
  children: ReactNode;
}) {
  if (!values.proseCards) return <>{children}</>;
  const chrome = buildCardChrome(
    {
      borderStyle: "box",
      backgroundOpacity: 0,
      accentColor: themeBorder,
      themeBorder,
      themeSurface,
    },
    compact,
  );
  return (
    <View style={chrome.outer}>
      <View style={chrome.inner}>{children}</View>
    </View>
  );
}
