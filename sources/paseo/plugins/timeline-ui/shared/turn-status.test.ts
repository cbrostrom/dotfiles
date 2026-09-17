import { describe, expect, it } from "vitest";
import {
  TURN_STATUS_RENDERER_KIND,
  TURN_STATUS_RENDERER_VERSION,
  turnStatusDataSchema,
  turnStatusLabel,
} from "./turn-status.js";

describe("turnStatusDataSchema", () => {
  it("parses failed outcome with optional code", () => {
    const withoutCode = turnStatusDataSchema.parse({ kind: "failed", message: "boom" });
    expect(withoutCode.kind).toBe("failed");
    const withCode = turnStatusDataSchema.parse({ kind: "failed", message: "boom", code: "E_X" });
    expect(withCode.kind === "failed" && withCode.code).toBe("E_X");
  });

  it("parses canceled outcome", () => {
    expect(turnStatusDataSchema.parse({ kind: "canceled", reason: "user" })).toEqual({
      kind: "canceled",
      reason: "user",
    });
  });

  it("rejects unknown kinds and missing fields", () => {
    expect(() => turnStatusDataSchema.parse({ kind: "completed" })).toThrow();
    expect(() => turnStatusDataSchema.parse({ kind: "failed" })).toThrow();
  });
});

describe("turnStatusLabel", () => {
  it("formats failed with and without code", () => {
    expect(turnStatusLabel({ kind: "failed", message: "boom" })).toBe("Turn failed: boom");
    expect(turnStatusLabel({ kind: "failed", message: "boom", code: "E_X" })).toBe(
      "Turn failed (E_X): boom",
    );
  });

  it("formats canceled", () => {
    expect(turnStatusLabel({ kind: "canceled", reason: "user" })).toBe("Canceled: user");
  });
});

describe("renderer identity", () => {
  it("is stable", () => {
    expect(TURN_STATUS_RENDERER_KIND).toBe("turn-status");
    expect(TURN_STATUS_RENDERER_VERSION).toBe(1);
  });
});
