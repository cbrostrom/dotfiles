import { describe, expect, it } from "vitest";
import { parseAttentionBlocks } from "./attention-blocks.js";

describe("parseAttentionBlocks", () => {
  it("returns null when no attention markers exist", () => {
    expect(parseAttentionBlocks("Plain assistant reply.")).toBeNull();
  });

  it("parses multiple blocks even with text between them", () => {
    const text = [
      "**→ One.** First.",
      "",
      "Middle note.",
      "",
      "**→ Two.** Second.",
    ].join("\n");

    expect(parseAttentionBlocks(text)?.blocks).toEqual([
      { title: "One", body: "First." },
      { title: "Two", body: "Second." },
    ]);
    expect(parseAttentionBlocks(text)?.segments).toEqual([
      { kind: "block", title: "One", body: "First." },
      { kind: "prose", text: "Middle note." },
      { kind: "block", title: "Two", body: "Second." },
    ]);
  });

  it("parses single-newline separated blocks in one paragraph", () => {
    const text = "**→ One.** First.\n**→ Two.** Second.\n**→ Three.** Third.";
    expect(parseAttentionBlocks(text)?.blocks).toEqual([
      { title: "One", body: "First." },
      { title: "Two", body: "Second." },
      { title: "Three", body: "Third." },
    ]);
  });

  it("keeps list continuations inside the same block body", () => {
    const text = ["**→ Title.** First line.", "- one", "- two", "", "**→ Two.** Second."].join("\n");

    expect(parseAttentionBlocks(text)?.blocks[0]).toEqual({
      title: "Title",
      body: "First line.\n- one\n- two",
    });
    expect(parseAttentionBlocks(text)?.segments).toEqual([
      { kind: "block", title: "Title", body: "First line.\n- one\n- two" },
      { kind: "block", title: "Two", body: "Second." },
    ]);
  });

  it("keeps structured Markdown inside a card across blank lines", () => {
    const text = [
      "**→ What landed.**",
      "",
      "- `shared/reasoning.ts` — settings schema",
      "- `client/reasoning/` — renderer",
      "",
      "**→ Next step.** Reload the plugin.",
    ].join("\n");

    expect(parseAttentionBlocks(text)?.segments).toEqual([
      {
        kind: "block",
        title: "What landed",
        body: [
          "- `shared/reasoning.ts` — settings schema",
          "- `client/reasoning/` — renderer",
        ].join("\n"),
      },
      { kind: "block", title: "Next step", body: "Reload the plugin." },
    ]);
  });

  it("keeps fenced code inside the same block body", () => {
    const text = ["**→ Run.** Try this:", "```bash", "npm test", "```"].join("\n");

    expect(parseAttentionBlocks(text)?.blocks[0]?.body).toBe(
      ["Try this:", "```bash", "npm test", "```"].join("\n"),
    );
  });

  it("parses intro, blocks, and outro", () => {
    const text = [
      "Short intro.",
      "",
      "**→ First point.** Body one.",
      "",
      "**→ Second point.** Body two.",
      "",
      "Closing note.",
    ].join("\n");

    expect(parseAttentionBlocks(text)).toEqual({
      intro: "Short intro.",
      blocks: [
        { title: "First point", body: "Body one." },
        { title: "Second point", body: "Body two." },
      ],
      outro: "Closing note.",
      segments: [
        { kind: "prose", text: "Short intro." },
        { kind: "block", title: "First point", body: "Body one." },
        { kind: "block", title: "Second point", body: "Body two." },
        { kind: "prose", text: "Closing note." },
      ],
    });
  });
});
