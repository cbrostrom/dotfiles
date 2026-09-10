import { describe, expect, it } from "vitest";
import { formatThinkingText, reasoningPreferences } from "./reasoning.js";
import { transformReasoning } from "./transform-reasoning.js";

describe("reasoning timeline", () => {
  it("creates a themed reasoning item and preserves its phase", () => {
    expect(
      transformReasoning({
        item: { type: "reasoning", text: "**Plan****Result**" },
        phase: "streaming",
      }),
    ).toEqual({
      items: [
        {
          type: "plugin",
          kind: "attention-reasoning",
          version: 1,
          data: { text: "**Plan**\n\n**Result**", phase: "streaming" },
        },
      ],
    });
  });

  it("does not rewrite inline or fenced code", () => {
    const text = "`**inline**`\n```\n**code****code**\n```";
    expect(formatThinkingText(text)).toBe(text);
  });

  it("defaults to expanding the latest reasoning card", () => {
    expect(reasoningPreferences.schema.parse({})).toEqual({ mode: "expand_last" });
  });
});
