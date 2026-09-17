import { describe, expect, it } from "vitest";
import { fnv1aHash, HOST_ACCENTS, hostAccentColor } from "./host-color.js";
import { cardAccentColor } from "./preferences.js";

describe("host color", () => {
  it("hashes deterministically", () => {
    expect(fnv1aHash("host-a")).toBe(fnv1aHash("host-a"));
    expect(fnv1aHash("host-a")).not.toBe(fnv1aHash("host-b"));
  });

  it("always returns a palette color, stable per host id", () => {
    for (const id of ["AKQABro - MacBook", "wks_1", "wks_2", ""]) {
      const color = hostAccentColor(id);
      expect(HOST_ACCENTS).toContain(color);
      expect(color).toBe(hostAccentColor(id));
    }
  });

  it("distributes across more than one palette entry for realistic host ids", () => {
    const ids = Array.from({ length: 20 }, (_, i) => `wks_${i}`);
    const distinct = new Set(ids.map(hostAccentColor));
    expect(distinct.size).toBeGreaterThan(1);
  });
});

describe("cardAccentColor", () => {
  const fallback = "#999999";

  it("returns the fallback when the switch is off", () => {
    expect(cardAccentColor({ hostColorAccent: false }, "host-a", fallback)).toBe(fallback);
  });

  it("returns the fallback when no host id is available", () => {
    expect(cardAccentColor({ hostColorAccent: true }, undefined, fallback)).toBe(fallback);
  });

  it("returns the host color when enabled", () => {
    expect(cardAccentColor({ hostColorAccent: true }, "host-a", fallback)).toBe(
      hostAccentColor("host-a"),
    );
  });
});
