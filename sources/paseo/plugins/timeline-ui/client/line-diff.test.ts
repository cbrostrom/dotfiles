import { describe, expect, it } from "vitest";
import { lineDiff } from "./line-diff.js";

describe("lineDiff", () => {
  it("returns same rows for identical text", () => {
    const rows = lineDiff("a\nb\nc", "a\nb\nc");
    expect(rows.every((r) => r.kind === "same")).toBe(true);
    expect(rows).toHaveLength(3);
  });

  it("aligns paired same lines across an edit", () => {
    const rows = lineDiff("const x = 1;\nconst y = 2;", "const x = 42;\nconst y = 2;");
    expect(rows.map((r) => r.kind)).toEqual(["removed", "same"]);
    expect(rows[0].left).toBe("const x = 1;");
    expect(rows[0].right).toBe("const x = 42;");
    expect(rows[1].left).toBe("const y = 2;");
  });

  it("handles pure insertions and removals", () => {
    expect(lineDiff("a\nc", "a\nb\nc").map((r) => r.kind)).toEqual(["same", "added", "same"]);
    expect(lineDiff("a\nb\nc", "a\nc").map((r) => r.kind)).toEqual(["same", "removed", "same"]);
  });

  it("pairs a replaced line into one row", () => {
    const rows = lineDiff("old line", "new line");
    expect(rows).toEqual([{ kind: "removed", left: "old line", right: "new line" }]);
  });

  it("does not crash on empty input", () => {
    expect(lineDiff("", "").map((r) => r.kind)).toEqual([]);
  });
});
