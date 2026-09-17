import { describe, expect, it } from "vitest";
import {
  attentionBlockMarkdown,
  attentionBlockPlainText,
  markdownToPlainText,
} from "./copy-block.js";

describe("attentionBlockMarkdown", () => {
  it("reconstructs the original **→ block markdown", () => {
    expect(attentionBlockMarkdown({ title: "Postal code", body: "Taiwan needs 5 digits." })).toBe(
      "**→ Postal code.**\nTaiwan needs 5 digits.",
    );
  });

  it("emits only the header when the body is empty", () => {
    expect(attentionBlockMarkdown({ title: "Header only", body: "" })).toBe("**→ Header only.**");
  });
});

describe("attentionBlockPlainText", () => {
  it("strips markdown from title and body", () => {
    const text = attentionBlockPlainText({
      title: "**Ticket reply**",
      body: "Use `write_validations` for **TW** postal codes.\n\n```regex\n/^\\d{5}$/\n```",
    });
    expect(text).toBe("Ticket reply\nUse write_validations for TW postal codes.\n/^\\d{5}$/");
  });
});

describe("markdownToPlainText", () => {
  it("renders headings, lists, and code as plain text", () => {
    const text = markdownToPlainText(
      ["## Done when", "", "- Missing codes block checkout", "- Others unaffected", "", "```regex", "/^\\d{5}$/", "```"].join("\n"),
    );
    expect(text).toBe("Done when\n• Missing codes block checkout\n• Others unaffected\n/^\\d{5}$/");
  });

  it("renders tables as pipe rows", () => {
    const text = markdownToPlainText("| Item | Detail |\n| --- | --- |\n| Gap | TW postal codes |");
    expect(text).toBe("Item | Detail\nGap | TW postal codes");
  });

  it("keeps ordered list markers and indentation", () => {
    const text = markdownToPlainText("1. First\n2. Second\n   - Nested");
    expect(text).toBe("1. First\n2. Second\n  • Nested");
  });
});

describe("attentionProseToBlock", () => {
  it("converts a stray **→ prose segment into a block", async () => {
    const { attentionProseToBlock } = await import("./attention-blocks.js");
    expect(attentionProseToBlock("**→ Done. Step 6 of 6 complete.**")).toEqual({
      title: "Done. Step 6 of 6 complete",
      body: "",
    });
    expect(attentionProseToBlock("**→ Done.**\nContinuation body.")).toEqual({
      title: "Done",
      body: "Continuation body.",
    });
    expect(attentionProseToBlock("plain prose")).toBeNull();
  });
});

describe("attentionProseToBlock (streaming fragments)", () => {
  it("tolerates an unclosed ** marker", async () => {
    const { attentionProseToBlock } = await import("./attention-blocks.js");
    expect(attentionProseToBlock("**→ Both")).toEqual({ title: "Both", body: "" });
    expect(attentionProseToBlock("**→ Both issues fixed. Plugin reloaded.**")).toEqual({
      title: "Both issues fixed. Plugin reloaded",
      body: "",
    });
  });
});
