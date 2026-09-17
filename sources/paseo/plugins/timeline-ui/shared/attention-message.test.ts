import { describe, expect, it } from "vitest";
import { stripLeadingBareMarker, isBareAttentionMarker, parseAttentionBlocks } from "./attention-blocks.js";

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
          version: 3,
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
          version: 3,
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
      version: 6,
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
    const text = ["[Cursor]", "", "**→ One.** First.", "Middle note.", "**→ Two.** Second."].join(
      "\n",
    );
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
      data: { text: "**Bold** and `code`." , phase: "complete" },
    });
  });

  it("suppresses a bare `**→`/`**` opener fragment instead of leaking raw markdown", () => {
    // Stream split around a reasoning block: header opener arrived alone.
    for (const text of ["**→", "**→ **", "**→ \n", "**→\n\n", "**"]) {
      const result = transformAssistantAttention({
        item: { type: "assistant_message", text },
        phase: "complete",
      });
      expect(result?.items[0]).toMatchObject({ kind: "markdown-message", data: { text: "" } });
    }
  });

  it("never treats a fragment with real content as a bare marker", () => {
    const result = transformAssistantAttention({
      item: { type: "assistant_message", text: "**→ Freed.** Body text." },
      phase: "complete",
    });
    expect(result?.items[0]).toMatchObject({ kind: "attention-message" });
    expect(isBareAttentionMarker("**→ Freed")).toBe(false);
  });

  it("stripLeadingBareMarker drops an opener line and keeps the body", () => {
    expect(stripLeadingBareMarker("**→\n\nFreed. Body")).toBe("Freed. Body");
    expect(stripLeadingBareMarker("**\n→ Yes.** Body")).toBe("→ Yes.** Body");
    expect(stripLeadingBareMarker("**→\n")).toBe("");
    expect(stripLeadingBareMarker("Plain text with **bold**.")).toBe(
      "Plain text with **bold**.",
    );
    expect(stripLeadingBareMarker("\n\nLeading blanks stay when no marker")).toBe(
      "\n\nLeading blanks stay when no marker",
    );
  });
});

describe("transformAssistantAttention: peer mail", () => {
  it("collapses a `[call:from=...]` marker assistant item into a call card", () => {
    const result = transformAssistantAttention({
      item: {
        type: "assistant_message",
        text: "[call:from=timeline-ui-settings-work] Done on my scope.",
      },
      phase: "complete",
    });
    expect(result?.items).toEqual([
      {
        type: "plugin",
        kind: "call-message",
        version: 2,
        data: {
          from: "timeline-ui-settings-work",
          body: "Done on my scope.",
          phase: "complete",
        },
      },
    ]);
  });

  it("collapses a full pi-peer envelope assistant item into a peer card", () => {
    const text = [
      "Message from pi session paseo-plugins#5d70 (/Users/x/paseo-plugins):",
      "",
      "Ack. My scope: reasoning only.",
    ].join("\n");
    const result = transformAssistantAttention({
      item: { type: "assistant_message", text },
      phase: "complete",
    });
    expect(result?.items[0]).toMatchObject({
      type: "plugin",
      kind: "peer-message",
      version: 2,
      data: { sender: "paseo-plugins#5d70", body: "Ack. My scope: reasoning only." },
    });
  });

  it("does not treat normal assistant text as peer mail", () => {
    const result = transformAssistantAttention({
      item: { type: "assistant_message", text: "Normal reply about sessions." },
      phase: "complete",
    });
    expect(result?.items[0]).toMatchObject({ kind: "markdown-message", version: 3 });
  });
});
