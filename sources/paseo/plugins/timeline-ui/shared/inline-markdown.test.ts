import { describe, expect, it } from "vitest";
import {
  flattenInlineMarkdown,
  parseInlineMarkdown,
  splitMarkdownBlocks,
} from "./inline-markdown.js";

describe("parseInlineMarkdown", () => {
  it("parses bold, code, and links", () => {
    expect(parseInlineMarkdown("**Root cause.** See `parser` and [docs](https://x.test).")).toEqual([
      { kind: "bold", value: "Root cause." },
      { kind: "text", value: " See " },
      { kind: "code", value: "parser" },
      { kind: "text", value: " and " },
      { kind: "link", label: "docs", href: "https://x.test" },
      { kind: "text", value: "." },
    ]);
  });

  it("leaves unmatched markers as plain text", () => {
    expect(parseInlineMarkdown("partial **bold")).toEqual([{ kind: "text", value: "partial **bold" }]);
  });
});

describe("splitMarkdownBlocks", () => {
  it("splits fenced code blocks", () => {
    expect(splitMarkdownBlocks("Before\n\n```ts\nconst x = 1;\n```\n\nAfter")).toEqual([
      { kind: "prose", text: "Before" },
      { kind: "code", text: "const x = 1;" },
      { kind: "prose", text: "After" },
    ]);
  });

  it("treats unclosed fences as code", () => {
    expect(splitMarkdownBlocks("Before\n```bash\nnpm test")).toEqual([
      { kind: "prose", text: "Before" },
      { kind: "code", text: "npm test" },
    ]);
  });
});

describe("flattenInlineMarkdown", () => {
  it("removes markers for heuristics", () => {
    expect(flattenInlineMarkdown("**Root cause.** `parser`")).toBe("Root cause. parser");
  });
});
