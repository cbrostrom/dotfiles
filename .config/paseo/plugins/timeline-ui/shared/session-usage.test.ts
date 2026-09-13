import { describe, expect, it } from "vitest";
import { formatSessionUsageLabel } from "./session-usage";

describe("formatSessionUsageLabel", () => {
  it("shows cumulative session cost", () => {
    expect(formatSessionUsageLabel({ totalCostUsd: 18.16075818 }, "cost")).toBe("$18.16");
  });

  it("adds compact token usage when requested", () => {
    expect(
      formatSessionUsageLabel(
        { totalCostUsd: 18.16075818, inputTokens: 950_902, outputTokens: 87_262 },
        "cost_tokens",
      ),
    ).toBe("$18.16 · 1M tok");
  });

  it("keeps the pill useful when a provider reports tokens without cost", () => {
    expect(formatSessionUsageLabel({ inputTokens: 12_500, outputTokens: 500 }, "cost_tokens")).toBe(
      "13k tok",
    );
  });
});
