import { describe, expect, it } from "vitest";
import { transformAssistantAttention } from "./transform-assistant-attention.js";

describe("transformAssistantAttention", () => {
  it("renders markdown fallback while streaming without markers", () => {
    expect(
      transformAssistantAttention({
        item: { type: "assistant_message", text: "Still writing…" },
        phase: "streaming",
      }),
    ).toEqual({
      items: [
        {
          type: "plugin",
          kind: "markdown-message",
          version: 1,
          data: { text: "Still writing…", phase: "streaming" },
        },
      ],
    });
  });

  it("streams attention-style output as markdown until complete", () => {
    expect(
      transformAssistantAttention({
        item: { type: "assistant_message", text: "**→ First.** Body" },
        phase: "streaming",
      }),
    ).toEqual({
      items: [
        {
          type: "plugin",
          kind: "markdown-message",
          version: 1,
          data: { text: "**→ First.** Body", phase: "streaming" },
        },
      ],
    });
  });

  it("replaces with attention cards when complete", () => {
    const text = ["**→ One.** First.", "", "**→ Two.** Second."].join("\n");
    const result = transformAssistantAttention({
      item: { type: "assistant_message", text },
      phase: "complete",
    });

    expect(result?.items).toHaveLength(1);
    expect(result?.items[0]).toMatchObject({
      type: "plugin",
      kind: "attention-message",
      version: 5,
      data: {
        intro: null,
        outro: null,
        phase: "complete",
        blocks: [
          { title: "One", body: "First.", variantIndex: 0 },
          { title: "Two", body: "Second.", variantIndex: 1 },
        ],
        segments: [
          { kind: "block", title: "One", body: "First.", variantIndex: 0 },
          { kind: "block", title: "Two", body: "Second.", variantIndex: 1 },
        ],
      },
    });
  });

  it("preserves intro and interstitial prose in segment order", () => {
    const text = ["[Cursor]", "", "**→ One.** First.", "Middle note.", "**→ Two.** Second."].join("\n");
    const result = transformAssistantAttention({
      item: { type: "assistant_message", text },
      phase: "complete",
    });

    expect(result?.items[0]).toMatchObject({
      kind: "attention-message",
      data: {
        intro: "[Cursor]",
        segments: [
          { kind: "prose", text: "[Cursor]" },
          { kind: "block", title: "One", body: "First." },
          { kind: "prose", text: "Middle note." },
          { kind: "block", title: "Two", body: "Second." },
        ],
      },
    });
  });

  it("uses markdown fallback for plain assistant replies", () => {
    const result = transformAssistantAttention({
      item: { type: "assistant_message", text: "**Bold** and `code`." },
      phase: "complete",
    });

    expect(result?.items[0]).toMatchObject({
      kind: "markdown-message",
      data: { text: "**Bold** and `code`.", phase: "complete" },
    });
  });
});
