import { describe, expect, it } from "vitest";
import { parseMarkdownDocument } from "./markdown-document.js";

describe("parseMarkdownDocument", () => {
  it("parses headings, lists, and code", () => {
    const text = ["## Title", "", "- one", "- two", "", "```ts", "const x = 1;", "```"].join("\n");
    expect(parseMarkdownDocument(text)).toEqual([
      { kind: "heading", level: 2, text: "Title" },
      { kind: "blank" },
      {
        kind: "list",
        ordered: false,
        items: [
          { indent: 0, text: "one" },
          { indent: 0, text: "two" },
        ],
      },
      { kind: "code", language: "ts", text: "const x = 1;" },
    ]);
  });

  it("parses simple tables", () => {
    const text = ["| A | B |", "| - | - |", "| 1 | 2 |"].join("\n");
    expect(parseMarkdownDocument(text)).toEqual([
      { kind: "table", headers: ["A", "B"], rows: [["1", "2"]] },
    ]);
  });

  it("strips incomplete inline from last paragraph when requested", () => {
    expect(parseMarkdownDocument("Hello **wor", false)).toEqual([{ kind: "paragraph", text: "Hello " }]);
  });
});
