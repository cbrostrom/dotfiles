import { describe, expect, it } from "vitest";
import { stripInlineMarkdown } from "./strip-markdown.js";

describe("stripInlineMarkdown", () => {
  it("removes bold markers", () => {
    expect(stripInlineMarkdown("**Root cause.** Parser bug.")).toBe("Root cause. Parser bug.");
  });

  it("flattens fenced code for heuristics", () => {
    expect(stripInlineMarkdown("Before ```ts\nconst x = 1;\n``` after")).toBe("Before const x = 1; after");
  });
});
