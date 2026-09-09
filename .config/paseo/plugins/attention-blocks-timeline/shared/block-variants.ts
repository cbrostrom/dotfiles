/**
 * Per-block chrome — plugin-owned palette (independent of theme accent).
 * Edit hex here for card stripe + icon colors; card fill still uses theme surfaces.
 */
/** Tuned for Zinc dark — vivid on #1f1f22 chat, not neon. */
export const BLOCK_VARIANTS = [
  { icon: "Sparkles", stripeColor: "#6ea8fe", iconColor: "#6ea8fe" },
  { icon: "CircleDot", stripeColor: "#b197fc", iconColor: "#b197fc" },
  { icon: "Zap", stripeColor: "#fbbf24", iconColor: "#fbbf24" },
  { icon: "Pin", stripeColor: "#f87171", iconColor: "#f87171" },
] as const;

export type BlockVariant = (typeof BLOCK_VARIANTS)[number];

export function blockVariant(index: number): BlockVariant {
  return BLOCK_VARIANTS[index % BLOCK_VARIANTS.length]!;
}
