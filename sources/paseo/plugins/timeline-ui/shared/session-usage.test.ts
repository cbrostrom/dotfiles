import { describe, expect, it } from "vitest";
import { estimateGoCostUsd } from "./opencode-go-prices";
import { displayCostUsd, formatSessionUsageLabel } from "./session-usage";

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
      "~$0.00 · 13k tok",
    );
  });

  it("estimates cost with a tilde when only tokens are reported", () => {
    // 12.5k input + 500 output under GLM-5.3-Flash: 0.0125*0.15 + 0.0005*0.5
    expect(formatSessionUsageLabel({ inputTokens: 12_500, outputTokens: 500 }, "cost")).toBe(
      "~$0.00",
    );
  });

  it("prefers reported cost over the estimate", () => {
    expect(displayCostUsd({ totalCostUsd: 0.5, inputTokens: 12_500, outputTokens: 500 })).toBe(0.5);
  });

  it("returns null when there is nothing to bill", () => {
    expect(displayCostUsd({})).toBeNull();
  });
});

describe("estimateGoCostUsd", () => {
  it("prices GLM-5.3-Flash tokens per 1M", () => {
    expect(estimateGoCostUsd({ inputTokens: 1_000_000, outputTokens: 1_000_000 })).toBeCloseTo(
      0.65,
      5,
    );
  });

  it("bills cached reads at the cacheRead rate", () => {
    expect(
      estimateGoCostUsd({ inputTokens: 1_000, cachedInputTokens: 55_000, outputTokens: 200 }),
    )!.toBeCloseTo(1_000 / 1e6 * 0.15 + 55_000 / 1e6 * 0.03 + 200 / 1e6 * 0.5, 8);
  });

  it("returns null without any token counts", () => {
    expect(estimateGoCostUsd({})).toBeNull();
  });
});
