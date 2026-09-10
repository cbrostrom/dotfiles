/**
 * Per-block chrome — plugin-owned palette (independent of theme accent).
 * Colors resolve at render time from variantIndex (see blockVariantIndex).
 */
/** Tuned for Zinc dark — vivid on #1f1f22 chat, not neon. Icons come from block-icon.ts. */
export const BLOCK_VARIANTS = [
  { stripeColor: "#6ea8fe" },
  { stripeColor: "#b197fc" },
  { stripeColor: "#fbbf24" },
  { stripeColor: "#f87171" },
  { stripeColor: "#34d399" },
  { stripeColor: "#fb923c" },
] as const;

export type BlockVariant = (typeof BLOCK_VARIANTS)[number];

/** Index within a message first; single-block messages vary by title hash. */
export function blockVariantIndex(title: string, indexInMessage: number): number {
  if (indexInMessage > 0) return indexInMessage % BLOCK_VARIANTS.length;
  let hash = 0;
  for (let i = 0; i < title.length; i++) {
    hash = (hash * 31 + title.charCodeAt(i)) >>> 0;
  }
  return hash % BLOCK_VARIANTS.length;
}

export function blockVariant(index: number): BlockVariant {
  return BLOCK_VARIANTS[index % BLOCK_VARIANTS.length]!;
}
