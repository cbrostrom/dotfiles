import { describe, expect, it } from "vitest";
import { BLOCK_VARIANTS, blockVariant, blockVariantName } from "./block-variants.js";

describe("semantic block variants", () => {
  it("maps successful outcomes to green", () => {
    expect(blockVariantName("Verification passed", "No new errors")).toBe("success");
    expect(blockVariant("Plugin is running").stripeColor).toBe(BLOCK_VARIANTS.success.stripeColor);
  });

  it("maps warnings to yellow", () => {
    expect(blockVariantName("Warning", "Review before deployment")).toBe("warning");
  });

  it("maps failures and errors to red", () => {
    expect(blockVariantName("Build failed")).toBe("error");
    expect(blockVariantName("Root cause", "A parser error broke the cards")).toBe("error");
  });

  it("maps UI and message content to purple", () => {
    expect(blockVariantName("Reasoning now matches the UI system")).toBe("message");
    expect(blockVariantName("Status update")).toBe("message");
  });

  it("maps plans and configuration actions to orange", () => {
    expect(blockVariantName("Next step")).toBe("action");
    expect(blockVariantName("Configure display")).toBe("action");
  });

  it("uses title semantics before body semantics", () => {
    expect(blockVariantName("Verification passed", "0 errors and no failures")).toBe("success");
  });

  it("uses blue for neutral content", () => {
    expect(blockVariantName("Architecture")).toBe("neutral");
  });
});
