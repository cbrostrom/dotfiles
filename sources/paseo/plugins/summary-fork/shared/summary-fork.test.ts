import { describe, expect, it } from "vitest";
import {
  capTranscript,
  collectTextMessages,
  parseSummarizerOutput,
  renderSummary,
  renderTranscript,
  scopeTranscript,
} from "./summary-fork";

const user = (text: string) => ({ type: "user_message", text });
const assistant = (text: string) => ({ type: "assistant_message", text });
const tool = () => ({ type: "tool_call" });
const compaction = (status: string) => ({ type: "compaction", status });
const completedCompaction = (summary: string) => ({
  type: "compaction",
  status: "completed",
  text: summary,
});

describe("collectTextMessages", () => {
  it("keeps only user and assistant text rows", () => {
    const entries = collectTextMessages([user("hi"), tool(), assistant("hello"), compaction("completed")]);
    expect(entries).toEqual([
      { kind: "user", text: "hi" },
      { kind: "assistant", text: "hello" },
    ]);
  });
});

describe("scopeTranscript", () => {
  const items = [
    user("one"),
    assistant("two"),
    tool(),
    compaction("loading"),
    completedCompaction("Compacted summary of earlier work"),
    user("three"),
    assistant("four"),
    user("five"),
  ];

  it("keeps the compaction summary plus the messages after it", () => {
    expect(scopeTranscript(items, "since_compaction")).toEqual([
      { kind: "summary", text: "Compacted summary of earlier work" },
      { kind: "user", text: "three" },
      { kind: "assistant", text: "four" },
      { kind: "user", text: "five" },
    ]);
  });

  it("works when a compaction row carries no text", () => {
    const bare = [user("one"), compaction("completed"), user("three")];
    expect(scopeTranscript(bare, "since_compaction")).toEqual([
      { kind: "user", text: "three" },
    ]);
  });

  it("uses the whole conversation for full scope", () => {
    // compaction rows without text are dropped; nothing else is
    expect(scopeTranscript(items, "full")).toHaveLength(5);
  });

  it("caps last-N scopes by message count", () => {
    expect(scopeTranscript(items, "last_10")).toEqual([
      { kind: "user", text: "one" },
      { kind: "assistant", text: "two" },
      { kind: "user", text: "three" },
      { kind: "assistant", text: "four" },
      { kind: "user", text: "five" },
    ]);
  });
});

describe("capTranscript", () => {
  it("trims oldest turns first and keeps the newest inside the cap", () => {
    const entries = [
      { kind: "user" as const, text: "x".repeat(50) },
      { kind: "assistant" as const, text: "y".repeat(50) },
      { kind: "user" as const, text: "z".repeat(10) },
    ];
    expect(capTranscript(entries, 30)).toEqual([entries[2]]);
  });

  it("keeps everything under the cap", () => {
    const entries = [{ kind: "user" as const, text: "short" }];
    expect(capTranscript(entries, 120_000)).toEqual(entries);
  });
});

describe("parseSummarizerOutput", () => {
  it("parses a JSON object embedded in prose", () => {
    const doc = parseSummarizerOutput('Here it is:\n{"goal":"g","currentState":"c","nextAction":"n"}');
    expect(doc).toEqual({
      goal: "g",
      currentState: "c",
      decisions: [],
      filesChanged: [],
      evidence: [],
      rejected: [],
      constraints: [],
      openQuestions: [],
      nextAction: "n",
    });
  });

  it("returns null for prose without JSON", () => {
    expect(parseSummarizerOutput("no json here")).toBeNull();
  });

  it("returns null for missing required fields", () => {
    expect(parseSummarizerOutput('{"goal":"g"}')).toBeNull();
  });
});

describe("renderSummary", () => {
  it("renders all non-empty sections", () => {
    const text = renderSummary(
      {
        goal: "Ship the fork",
        currentState: "Plugin registered",
        decisions: ["Use virtual attachment"],
        filesChanged: [],
        evidence: ["47 tests pass"],
        rejected: ["Filesystem summary file"],
        constraints: [],
        openQuestions: ["Upstream region API?"],
        nextAction: "Create the fork chat",
      },
      "Source chat",
    );
    expect(text).toContain("# Fork summary — Source chat");
    expect(text).toContain("- Use virtual attachment");
    expect(text).toContain("# Recommended next action\nCreate the fork chat");
    expect(text).not.toContain("# Files changed");
  });
});

describe("renderTranscript", () => {
  it("labels each row", () => {
    expect(renderTranscript([
      { kind: "user", text: "hi" },
      { kind: "assistant", text: "hello" },
    ])).toBe("## User\nhi\n\n## Assistant\nhello");
  });
});
