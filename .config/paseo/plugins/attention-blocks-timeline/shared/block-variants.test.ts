import { describe, expect, it } from "vitest";
import { blockVariant, blockVariantIndex } from "./block-variants.js";

describe("blockVariantIndex", () => {
  it("uses message index for multi-block messages", () => {
    expect(blockVariantIndex("A", 0)).toBe(0);
    expect(blockVariantIndex("B", 1)).toBe(1);
    expect(blockVariantIndex("C", 2)).toBe(2);
  });

  it("varies single-block messages by title", () => {
    const a = blockVariantIndex("Root cause", 0);
    const b = blockVariantIndex("Recommended setup", 0);
    expect(a).not.toBe(b);
  });

  it("cycles six palette slots", () => {
    expect(blockVariant(6).stripeColor).toBe(blockVariant(0).stripeColor);
  });
});
