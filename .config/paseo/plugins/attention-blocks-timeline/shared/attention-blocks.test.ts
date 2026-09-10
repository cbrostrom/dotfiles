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
  });

  it("parses single-newline separated blocks in one paragraph", () => {
    const text = "**→ One.** First.\n**→ Two.** Second.\n**→ Three.** Third.";
    expect(parseAttentionBlocks(text)?.blocks).toEqual([
      { title: "One", body: "First." },
      { title: "Two", body: "Second." },
      { title: "Three", body: "Third." },
    ]);
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
    });
  });
});
