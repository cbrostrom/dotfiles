import type { ComposerPreferences } from "./composer-preferences";

export interface SessionUsage {
  inputTokens?: number;
  cachedInputTokens?: number;
  outputTokens?: number;
  totalCostUsd?: number;
  contextWindowMaxTokens?: number;
  contextWindowUsedTokens?: number;
}

function formatTokens(value: number): string {
  if (value < 1_000) return String(value);
  if (value < 1_000_000) return `${Math.round(value / 1_000)}k`;
  const millions = value / 1_000_000;
  return `${millions >= 10 ? Math.round(millions) : millions.toFixed(1).replace(/\.0$/, "")}M`;
}

function totalTokens(usage: SessionUsage): number | null {
  const input = usage.inputTokens ?? 0;
  const output = usage.outputTokens ?? 0;
  return input > 0 || output > 0 ? input + output : null;
}

export function formatSessionUsageLabel(
  usage: SessionUsage | null | undefined,
  mode: ComposerPreferences["usageDisplay"],
): string {
  const cost = usage?.totalCostUsd;
  const costLabel = cost === undefined ? null : `$${cost.toFixed(2)}`;
  if (mode === "cost") return costLabel ?? "Cost —";

  const tokens = usage ? totalTokens(usage) : null;
  const tokenLabel = tokens === null ? null : `${formatTokens(tokens)} tok`;
  if (costLabel && tokenLabel) return `${costLabel} · ${tokenLabel}`;
  return costLabel ?? tokenLabel ?? "Usage —";
}

export function formatTokenCount(value: number | undefined): string {
  return value === undefined ? "—" : formatTokens(value);
}
