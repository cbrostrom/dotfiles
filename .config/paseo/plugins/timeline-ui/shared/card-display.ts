import type { CardPreferences } from "./preferences.js";

export const ACCENT_STRIPE_WIDTH = 4;
export const ACCENT_BAR_HEIGHT = 3;

export interface CardChromeInput {
  borderStyle: CardPreferences["borderStyle"];
  backgroundOpacity: number;
  accentColor: string;
  themeBorder: string;
  themeSurface: string;
}

export interface CardChromeStyle {
  outer: {
    alignSelf: "stretch";
    overflow: "visible";
    borderRadius: number;
    flexDirection?: "row" | "column";
  };
  stripe: { width: number; backgroundColor: string } | null;
  accentBar: { height: number; backgroundColor: string } | null;
  inner: {
    flexGrow: number;
    flexShrink: number;
    gap: number;
    paddingHorizontal: number;
    paddingVertical: number;
    borderWidth: number;
    borderColor: string;
    borderRadius: number;
    backgroundColor: string;
  };
}

export function hexToRgba(hex: string, alpha: number): string {
  const h = hex.replace("#", "");
  if (h.length !== 6 || alpha <= 0) return "transparent";
  const r = Number.parseInt(h.slice(0, 2), 16);
  const g = Number.parseInt(h.slice(2, 4), 16);
  const b = Number.parseInt(h.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function innerBackground(input: CardChromeInput): string {
  if (input.backgroundOpacity <= 0) return input.themeSurface;
  return hexToRgba(input.accentColor, input.backgroundOpacity);
}

export function buildCardChrome(
  input: CardChromeInput,
  compact: boolean,
): CardChromeStyle {
  const padH = compact ? 12 : 14;
  const padV = compact ? 10 : 11;
  const gap = compact ? 4 : 6;
  const radius = 8;
  const bg = innerBackground(input);

  const baseInner = {
    flexGrow: 1 as const,
    flexShrink: 0 as const,
    gap,
    paddingHorizontal: padH,
    paddingVertical: padV,
    borderRadius: radius,
    backgroundColor: bg,
  };

  switch (input.borderStyle) {
    case "none":
      return {
        outer: { alignSelf: "stretch", overflow: "visible", borderRadius: radius },
        stripe: null,
        accentBar: null,
        inner: { ...baseInner, borderWidth: 0, borderColor: "transparent" },
      };
    case "left":
      return {
        outer: {
          alignSelf: "stretch",
          overflow: "visible",
          borderRadius: radius,
          flexDirection: "row",
        },
        stripe: { width: ACCENT_STRIPE_WIDTH, backgroundColor: input.accentColor },
        accentBar: null,
        inner: { ...baseInner, borderWidth: 0, borderColor: "transparent" },
      };
    case "top":
      return {
        outer: {
          alignSelf: "stretch",
          overflow: "visible",
          borderRadius: radius,
          flexDirection: "column",
        },
        stripe: null,
        accentBar: { height: ACCENT_BAR_HEIGHT, backgroundColor: input.accentColor },
        inner: { ...baseInner, borderWidth: 0, borderColor: "transparent" },
      };
    case "box":
    default:
      return {
        outer: { alignSelf: "stretch", overflow: "visible", borderRadius: radius },
        stripe: null,
        accentBar: null,
        inner: {
          ...baseInner,
          borderWidth: 1,
          borderColor: input.themeBorder,
        },
      };
  }
}
