import { describe, expect, it } from "vitest";
import { classifyProseShape, parseLeadInBlock } from "./prose-shape.js";

describe("parseLeadInBlock", () => {
  it("extracts title and body from a bold lead-in with colon", () => {
    expect(parseLeadInBlock("**Bottom line:** the card is a one-liner.")).toEqual({
      title: "Bottom line",
      body: "the card is a one-liner.",
    });
  });

  it("accepts period and question-mark closers", () => {
    expect(parseLeadInBlock("**Step 1 of 3 done.** Next: tests.")).toEqual({
      title: "Step 1 of 3 done",
      body: "Next: tests.",
    });
    expect(parseLeadInBlock("**Seen this before?** Yes, twice.")).toEqual({
      title: "Seen this before",
      body: "Yes, twice.",
    });
  });

  it("keeps the title short and rejects bolded sentences", () => {
    expect(parseLeadInBlock("**One two three four five six seven eight nine.** Body.")).toBeNull();
  });

  it("requires a non-empty body", () => {
    expect(parseLeadInBlock("**Just bold.**")).toBeNull();
    expect(parseLeadInBlock("**Just bold.** ")).toBeNull();
  });

  it("ignores attention-marker territory", () => {
    expect(parseLeadInBlock("**→ Title.** Body")).toBeNull();
  });
});

describe("classifyProseShape", () => {
  it("classifies short plain one-liners as headlines", () => {
    expect(classifyProseShape("Plan, awaiting go.")).toEqual({
      kind: "headline",
      text: "Plan, awaiting go.",
    });
    expect(classifyProseShape("Revised outline, awaiting approval.")).toEqual({
      kind: "headline",
      text: "Revised outline, awaiting approval.",
    });
  });

  it("classifies wholesale-bold short one-liners as headlines", () => {
    expect(classifyProseShape("**Awaiting go.**")).toEqual({ kind: "headline", text: "**Awaiting go.**" });
  });

  it("keeps structured markdown in the rich card path", () => {
    expect(classifyProseShape("- one\n- two").kind).toBe("rich");
    expect(classifyProseShape("## Heading\n\nBody.").kind).toBe("rich");
    expect(classifyProseShape("```\ncode\n```").kind).toBe("rich");
    expect(classifyProseShape("First para\n\nSecond para.").kind).toBe("rich");
    expect(classifyProseShape("").kind).toBe("rich");
  });

  it("classifies single paragraphs with inline formatting as plain prose", () => {
    const text = "Research **confirmed:** no stored per-project color.";
    expect(classifyProseShape(text)).toEqual({ kind: "plain", text });
  });

  it("routes lead-in paragraphs to a titled block", () => {
    expect(classifyProseShape("**Bottom line:** the card is a one-liner.")).toEqual({
      kind: "leadIn",
      title: "Bottom line",
      body: "the card is a one-liner.",
    });
  });

  it("keeps long plain sentences in the plain path", () => {
    const long = "A plain sentence that rambles well past the headline threshold so it no longer reads like a title at all.";
    expect(classifyProseShape(long)).toEqual({ kind: "plain", text: long });
  });
});
