import { describe, expect, it } from "vitest";
import {
  DEFAULT_MESSAGE_PREFERENCES,
  messagePreferences,
} from "./message-preferences.js";

/**
 * Regression: docs stored by older plugin versions predate keys such as
 * `peerCards`. The zod schema must fill every missing key from its defaults so
 * a stored subset never disables a renderer silently.
 */
describe("messagePreferences", () => {
  it("fills missing keys with defaults for a legacy stored doc", () => {
    const legacy = {
      attentionCards: true,
      proseDensity: "comfortable",
      codeStyle: "subtle",
      stableStreaming: true,
    };
    const parsed = messagePreferences.schema.parse(legacy);
    expect(parsed.peerCards).toBe(true);
    expect(parsed.peerCardStyle).toBe("bubble");
    expect(parsed.proseCards).toBe(true);
  });

  it("DEFAULT_MESSAGE_PREFERENCES carries every schema key", () => {
    const schemaKeys = new Set(Object.keys(DEFAULT_MESSAGE_PREFERENCES));
    for (const key of [
      "attentionCards",
      "proseCards",
      "proseDensity",
      "codeStyle",
      "stableStreaming",
      "peerCards",
      "peerCardStyle",
    ]) {
      expect(schemaKeys.has(key)).toBe(true);
    }
  });
});
