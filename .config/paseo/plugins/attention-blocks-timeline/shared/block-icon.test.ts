import { describe, expect, it } from "vitest";
import { inferBlockIcon } from "./block-icon.js";

describe("inferBlockIcon", () => {
  it("returns null for generic prose", () => {
    expect(inferBlockIcon("Hello", "Some plain text.")).toBeNull();
  });

  it("prefers title over body", () => {
    expect(inferBlockIcon("Theme vs card colors", "Parser bug fixed.")).toBe("Palette");
  });

  it("matches common attention lead-ins", () => {
    expect(inferBlockIcon("Root cause", "Streaming duplicated cards.")).toBe("Bug");
    expect(inferBlockIcon("Recommended setup", "Use Zinc in Appearance.")).toBe("ListChecks");
    expect(inferBlockIcon("Not possible", "Plugin cannot clone Zinc exactly.")).toBe("CircleX");
  });

  it("falls back to body when title is generic", () => {
    expect(inferBlockIcon("Details", "Commit this before more changes.")).toBe("GitCommit");
  });
});
