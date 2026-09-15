import { describe, expect, it } from "vitest";
import { buildCardChrome, hexToRgba } from "./card-display.js";

describe("buildCardChrome", () => {
  const base = {
    accentColor: "#6ea8fe",
    themeBorder: "#303036",
    themeSurface: "#1f1f22",
    backgroundOpacity: 0.11,
  };

  it("removes border when style is none", () => {
    const chrome = buildCardChrome({ ...base, borderStyle: "none" }, false);
    expect(chrome.inner.borderWidth).toBe(0);
    expect(chrome.stripe).toBeNull();
  });

  it("adds left stripe for left style", () => {
    const chrome = buildCardChrome({ ...base, borderStyle: "left" }, false);
    expect(chrome.stripe?.width).toBe(4);
    expect(chrome.outer.flexDirection).toBe("row");
  });

  it("uses surface when opacity is zero", () => {
    const chrome = buildCardChrome({ ...base, borderStyle: "box", backgroundOpacity: 0 }, false);
    expect(chrome.inner.backgroundColor).toBe("#1f1f22");
  });
});

describe("hexToRgba", () => {
  it("returns transparent at zero alpha", () => {
    expect(hexToRgba("#6ea8fe", 0)).toBe("transparent");
  });
});
