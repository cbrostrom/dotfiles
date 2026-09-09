import { describe, expect, it } from "vitest";
import { stripInlineMarkdown } from "./strip-markdown.js";

describe("stripInlineMarkdown", () => {
  it("removes bold markers", () => {
    expect(stripInlineMarkdown("**Root cause.** Parser bug.")).toBe("Root cause. Parser bug.");
  });
});
