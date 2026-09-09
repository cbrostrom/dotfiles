import { describe, expect, it } from "vitest";
import { transformAssistantAttention } from "./attention-message.js";

describe("transformAssistantAttention", () => {
  it("keeps original while streaming without markers", () => {
    expect(
      transformAssistantAttention({
        item: { type: "assistant_message", text: "Still writing…" },
        phase: "streaming",
      }),
    ).toBeUndefined();
  });

  it("hides raw markdown while streaming attention-style output", () => {
    expect(
      transformAssistantAttention({
        item: { type: "assistant_message", text: "**→ First.** Body" },
        phase: "streaming",
      }),
    ).toEqual({ items: [] });
  });

  it("replaces with one plugin row when complete", () => {
    const text = ["**→ One.** First.", "", "**→ Two.** Second."].join("\n");
    const result = transformAssistantAttention({
      item: { type: "assistant_message", text },
      phase: "complete",
    });

    expect(result?.items).toHaveLength(1);
    expect(result?.items[0]).toMatchObject({
      type: "plugin",
      kind: "attention-message",
      version: 2,
      data: {
        intro: null,
        outro: null,
        phase: "complete",
        blocks: [
          { title: "One", body: "First.", stripeColor: "#6ea8fe", icon: "Sparkles" },
          { title: "Two", body: "Second.", stripeColor: "#b197fc", icon: "CircleDot" },
        ],
      },
    });
  });
});
