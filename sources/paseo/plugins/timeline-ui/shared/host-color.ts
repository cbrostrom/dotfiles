/**
 * Per-host chat accent colors.
 *
 * Paseo does not expose a user-assigned host/project color to plugins, so each
 * host gets a stable color derived from a FNV-1a hash of its id. Same host
 * always gets the same color; different hosts in one workspace diverge. When
 * Paseo ships a real host color field, prefer it and fall back to this hash.
 */

export const HOST_ACCENTS = [
  "#fb923c", // orange
  "#38bdf8", // sky
  "#a78bfa", // violet
  "#34d399", // emerald
  "#f472b6", // pink
  "#facc15", // yellow
  "#22d3ee", // cyan
  "#fb7185", // rose
] as const;

/** 32-bit FNV-1a hash, returned as an unsigned integer. */
export function fnv1aHash(input: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < input.length; i += 1) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash;
}

/** Stable accent color for a host id. */
export function hostAccentColor(hostId: string): string {
  return HOST_ACCENTS[fnv1aHash(hostId) % HOST_ACCENTS.length];
}
