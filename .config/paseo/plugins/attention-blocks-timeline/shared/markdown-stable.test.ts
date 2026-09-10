import { describe, expect, it } from "vitest";
import { partitionMarkdown, stripIncompleteInline } from "./markdown-stable.js";

describe("partitionMarkdown", () => {
  it("returns all text when complete", () => {
    expect(partitionMarkdown("Hello **world**", "complete")).toEqual({
      stable: "Hello **world**",
      tail: "",
    });
  });

  it("holds unclosed code fence in tail while streaming", () => {
    expect(partitionMarkdown("Before\n```bash\nnpm test", "streaming")).toEqual({
      stable: "Before",
      tail: "```bash\nnpm test",
    });
  });

  it("holds trailing paragraph in tail while streaming", () => {
    expect(partitionMarkdown("Done paragraph.\n\nStill typing", "streaming")).toEqual({
      stable: "Done paragraph.",
      tail: "Still typing",
    });
  });
});

describe("stripIncompleteInline", () => {
  it("moves trailing open bold to fragment", () => {
    expect(stripIncompleteInline("Hello **wor")).toEqual({
      complete: "Hello ",
      fragment: "**wor",
    });
  });
});
