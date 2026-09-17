import { describe, expect, it } from "vitest";
import {
  formatThinkingText,
  isMidAnswerThinking,
  reasoningPreferences,
  thinkingLabelFor,
  THINKING_LABELS,
} from "./reasoning.js";
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
          version: 2,
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
    expect(reasoningPreferences.schema.parse({})).toEqual({
      mode: "expand_last",
      rotateLabel: false,
      revealHidden: false,
    });
  });

  it("classifies mid-answer thinking from the assistant clock", () => {
    // Sandwiched: a later assistant fragment has a newer timestamp.
    expect(isMidAnswerThinking(100, 200, false)).toBe(true);
    // Trailing: nothing assistant-text after it.
    expect(isMidAnswerThinking(300, 200, false)).toBe(false);
    // Equal timestamps are ambiguous — never hide on a tie.
    expect(isMidAnswerThinking(200, 200, false)).toBe(false);
    // While streaming it is the live item, never mid-answer.
    expect(isMidAnswerThinking(100, 200, true)).toBe(false);
  });

  it("picks a stable thinking label per key and stays inside the phrase list", () => {
    expect(thinkingLabelFor("agent-1:1000")).toBe(thinkingLabelFor("agent-1:1000"));
    expect(thinkingLabelFor("agent-1:1000")).not.toBe(thinkingLabelFor("agent-1:1001"));
    for (const key of ["a", "b", "agent-2:99", "x:yz", ""]) {
      expect(THINKING_LABELS).toContain(thinkingLabelFor(key));
    }
  });
});
