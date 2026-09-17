import { describe, expect, it } from "vitest";
import {
  isContinuationFragment,
  noteAssistantFragment,
  readLastAssistantFragment,
  type AssistantFragmentInfo,
} from "./assistant-clock.js";

describe("assistant-clock continuation classification", () => {
  it("flags a no-marker fragment right after a marker fragment", () => {
    noteAssistantFragment(true, "**→ Bottom line.** Forking works legally (Apache-2.0");
    const prev = readLastAssistantFragment();
    expect(isContinuationFragment(") and you can keep pulling upstream.", prev)).toBe(true);
  });

  it("rejects when the previous fragment had no marker", () => {
    noteAssistantFragment(false, "Plain answer.");
    const prev = readLastAssistantFragment();
    expect(isContinuationFragment(") and more text.", prev)).toBe(false);
  });

  it("treats a clean sentence end plus capital start as a separate message", () => {
    const prev: AssistantFragmentInfo = {
      hadMarker: true,
      text: "**→ Bottom line.** Done. That is the answer.",
      at: Date.now(),
    };
    expect(isContinuationFragment("Next, here is something else.", prev)).toBe(false);
  });

  it("flags a lowercase start even after terminal punctuation", () => {
    const prev: AssistantFragmentInfo = {
      hadMarker: true,
      text: "**→ Bottom line.** Works (Apache-2.0).",
      at: Date.now(),
    };
    expect(isContinuationFragment("and you can keep pulling upstream.", prev)).toBe(true);
  });
});
