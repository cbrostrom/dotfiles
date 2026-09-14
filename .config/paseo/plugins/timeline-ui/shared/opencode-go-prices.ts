/**
 * OpenCode Go per-model token prices (USD per 1M tokens).
 *
 * Source of truth: https://opencode.ai/docs/go/#usage-limits
 * Collected: 2026-09-14. Refresh by re-reading that page and updating this
 * table; pi's own models-store carries the same prices, so this module is the
 * fallback estimator for sessions whose usage arrives without a cost figure.
 */

export interface GoModelPrice {
  /** USD per 1M input tokens. */
  input: number;
  /** USD per 1M output tokens. */
  output: number;
  /** USD per 1M cached-read tokens. */
  cacheRead: number;
  /** USD per 1M cached-write tokens; absent when the model has none. */
  cacheWrite?: number;
  /** Subscription monthly dollar cap for the model. */
  monthlyLimit: number;
  /** Qualifier from the docs, e.g. context tier or peak/off-peak window. */
  note?: string;
}

const TABLE = {
  "glm-5.3-flash": { input: 0.15, output: 0.5, cacheRead: 0.03, monthlyLimit: 60 },
  "glm-5.3": { input: 1.4, output: 4.4, cacheRead: 0.26, monthlyLimit: 15 },
  "glm-5.2": { input: 1.4, output: 4.4, cacheRead: 0.26, monthlyLimit: 60 },
  "glm-5.1": { input: 1.4, output: 4.4, cacheRead: 0.26, monthlyLimit: 60 },
  "kimi-k3": { input: 3.0, output: 15.0, cacheRead: 0.3, monthlyLimit: 15 },
  "kimi-k2.7-code": { input: 0.95, output: 4.0, cacheRead: 0.19, monthlyLimit: 60 },
  "kimi-k2.6": { input: 0.95, output: 4.0, cacheRead: 0.16, monthlyLimit: 60 },
  "longcat-2.0": { input: 0.3, output: 1.2, cacheRead: 0.006, monthlyLimit: 60 },
  "mimo-v2.5": { input: 0.14, output: 0.28, cacheRead: 0.0028, monthlyLimit: 60 },
  "mimo-v2.5-pro": { input: 0.435, output: 0.87, cacheRead: 0.003625, monthlyLimit: 15 },
  "minimax-m3": { input: 0.3, output: 1.2, cacheRead: 0.06, monthlyLimit: 60 },
  "minimax-m2.7": { input: 0.3, output: 1.2, cacheRead: 0.06, cacheWrite: 0.375, monthlyLimit: 60 },
  "minimax-m2.5": { input: 0.3, output: 1.2, cacheRead: 0.06, cacheWrite: 0.375, monthlyLimit: 60 },
  "muse-spark-1.3-contributor": { input: 0.1, output: 0.2, cacheRead: 0.002, monthlyLimit: 60 },
  "muse-spark-1.2-contributor": { input: 0.1, output: 0.2, cacheRead: 0.002, monthlyLimit: 60 },
  "qwen3.8-max": { input: 2.0, output: 6.0, cacheRead: 0.25, cacheWrite: 2.5, monthlyLimit: 15 },
  "qwen3.8-flash": { input: 0.15, output: 0.47, cacheRead: 0.016, cacheWrite: 0.2, monthlyLimit: 30 },
  "qwen3.7-max": { input: 2.5, output: 7.5, cacheRead: 0.5, cacheWrite: 3.125, monthlyLimit: 30 },
  "qwen3.7-plus": { input: 0.4, output: 1.6, cacheRead: 0.04, cacheWrite: 0.5, monthlyLimit: 60, note: "≤256K context tier" },
  "qwen3.6-plus": { input: 0.5, output: 3.0, cacheRead: 0.05, cacheWrite: 0.625, monthlyLimit: 60, note: "≤256K context tier" },
  "deepseek-v4.1-flash": { input: 0.15, output: 0.6, cacheRead: 0.003, monthlyLimit: 60, note: "off-peak; peak ×2 (01-04, 06-10 UTC Mon-Fri)" },
  "deepseek-v4-pro": { input: 0.66, output: 1.98, cacheRead: 0.022, monthlyLimit: 15, note: "off-peak; peak ×2" },
  "deepseek-v4-flash": { input: 0.15, output: 0.6, cacheRead: 0.003, monthlyLimit: 30, note: "off-peak; peak ×2" },
  "deepseek-v4-flash-vision-exp": { input: 0.15, output: 0.6, cacheRead: 0.003, monthlyLimit: 15, note: "off-peak; peak ×2" },
  "hy4-preview": { input: 0.834, output: 2.501, cacheRead: 0.042, monthlyLimit: 30 },
  hy3: { input: 0.14, output: 0.58, cacheRead: 0.035, monthlyLimit: 60 },
  "grok-4.6": { input: 2.0, output: 6.0, cacheRead: 0.5, monthlyLimit: 15, note: "≤200K context tier" },
  "gpt-5.6-luna": { input: 0.2, output: 1.2, cacheRead: 0.02, cacheWrite: 0.25, monthlyLimit: 15, note: "≤272K context tier" },
} satisfies Record<string, GoModelPrice>;

export type GoModelId = keyof typeof TABLE;

/** Christian's standard Go model; used when the session model is unknown. */
export const DEFAULT_GO_MODEL: GoModelId = "glm-5.3-flash";

export function goPriceFor(modelId: string): GoModelPrice | null {
  const price = TABLE[modelId as GoModelId];
  return price ?? null;
}

export interface GoTokenUsage {
  inputTokens?: number;
  cachedInputTokens?: number;
  outputTokens?: number;
}

/**
 * Estimated USD cost for a token count under OpenCode Go pricing.
 * Falls back to the default model when the model id is unknown.
 * Returns null when there is no token data at all.
 */
export function estimateGoCostUsd(
  usage: GoTokenUsage,
  modelId?: string | null,
): number | null {
  const input = usage.inputTokens ?? 0;
  const cached = usage.cachedInputTokens ?? 0;
  const output = usage.outputTokens ?? 0;
  if (input === 0 && cached === 0 && output === 0) return null;
  const price = goPriceFor(modelId ?? "") ?? TABLE[DEFAULT_GO_MODEL];
  const perMillion =
    input * price.input +
    cached * price.cacheRead +
    output * price.output +
    0; // cacheWrite is not reported by session usage
  return perMillion / 1_000_000;
}
