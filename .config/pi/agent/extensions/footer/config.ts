import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import type {
  ColorScheme,
  FooterEffectiveConfig,
  FooterPreset,
  FooterUserConfig,
  StatusLineSegmentId,
  StatusLineSegmentOptions,
} from "./types.js";
import { getDefaultColors } from "./theme.js";
import type { IconSet } from "./icons.js";

export const DEFAULT_CONTEXT_WARNING = 70;
export const DEFAULT_CONTEXT_DANGER = 90;

export interface SegmentRows {
  row1LeftSegments: StatusLineSegmentId[];
  row1RightSegments: StatusLineSegmentId[];
  row2LeftSegments: StatusLineSegmentId[];
  row2RightSegments: StatusLineSegmentId[];
}

/** Named layouts borrowed from pi-atelier (editorial / minimal / classic). */
export const PRESETS: Record<Exclude<FooterPreset, "custom">, SegmentRows> = {
  editorial: {
    row1LeftSegments: ["activity", "separator", "pi", "separator", "model", "separator", "path", "git"],
    row1RightSegments: ["context_pct"],
    row2LeftSegments: ["thinking", "separator", "caveman", "separator", "plan_mode", "separator", "chat_mode"],
    // copilot_usage hides itself unless provider === github-copilot
    row2RightSegments: ["token_total", "separator", "copilot_usage", "separator", "cost"],
  },
  minimal: {
    row1LeftSegments: ["activity", "separator", "model", "separator", "path"],
    row1RightSegments: ["context_pct"],
    row2LeftSegments: ["thinking"],
    row2RightSegments: ["copilot_usage", "separator", "cost"],
  },
  classic: {
    row1LeftSegments: ["activity", "separator", "model", "separator", "path", "git"],
    row1RightSegments: ["context_pct"],
    row2LeftSegments: ["thinking", "separator", "plan_mode", "separator", "chat_mode"],
    row2RightSegments: ["token_in", "separator", "token_out", "separator", "cache_read", "separator", "copilot_usage", "separator", "cost"],
  },
};

const DEFAULT_SEGMENT_OPTIONS: StatusLineSegmentOptions = {
  path: { mode: "full" },
  git: {
    showBranch: true,
    showStaged: true,
    showUnstaged: true,
    showUntracked: true,
  },
};

// Cache for user config
let userConfigCache: FooterUserConfig | null = null;
let userConfigCacheTime = 0;
const CACHE_TTL = 5000; // 5 seconds

export function getConfigPath(): string {
  const homeDir = process.env.HOME || process.env.USERPROFILE || "";
  return join(homeDir, ".pi", "agent", "configs", "footer.json");
}

function clampPercent(value: unknown, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.min(100, Math.max(0, value));
}

function isPresetName(value: unknown): value is FooterPreset {
  return value === "editorial" || value === "minimal" || value === "classic" || value === "custom";
}

export function loadUserConfig(): FooterUserConfig | null {
  const now = Date.now();
  if (userConfigCache && now - userConfigCacheTime < CACHE_TTL) {
    return userConfigCache;
  }

  const configPath = getConfigPath();
  try {
    if (existsSync(configPath)) {
      const content = readFileSync(configPath, "utf-8");
      const parsed = JSON.parse(content);
      userConfigCache = parsed as FooterUserConfig;
      userConfigCacheTime = now;
      return userConfigCache;
    }
  } catch {
    // Ignore errors, return null
  }

  userConfigCache = null;
  userConfigCacheTime = now;
  return null;
}

export function clearUserConfigCache(): void {
  userConfigCache = null;
  userConfigCacheTime = 0;
}

/** Persist a partial patch into footer.json (merge with existing). */
export function saveUserConfigPatch(patch: FooterUserConfig): FooterUserConfig {
  const current = loadUserConfig() ?? {};
  const next: FooterUserConfig = { ...current, ...patch };

  // Named presets own the row layout — drop stale custom rows so they cannot fight the preset.
  if (patch.preset && patch.preset !== "custom") {
    delete next.row1LeftSegments;
    delete next.row1RightSegments;
    delete next.row2LeftSegments;
    delete next.row2RightSegments;
  }

  const configPath = getConfigPath();
  mkdirSync(dirname(configPath), { recursive: true });
  writeFileSync(configPath, `${JSON.stringify(next, null, 2)}\n`, "utf-8");
  clearUserConfigCache();
  userConfigCache = next;
  userConfigCacheTime = Date.now();
  return next;
}

function resolveRows(userConfig: FooterUserConfig | null): SegmentRows & { preset: FooterPreset } {
  const preset = isPresetName(userConfig?.preset) ? userConfig.preset : "editorial";

  if (preset !== "custom") {
    return { preset, ...PRESETS[preset] };
  }

  // custom: explicit rows, falling back to editorial
  const base = PRESETS.editorial;
  return {
    preset,
    row1LeftSegments: userConfig?.row1LeftSegments ?? base.row1LeftSegments,
    row1RightSegments: userConfig?.row1RightSegments ?? base.row1RightSegments,
    row2LeftSegments: userConfig?.row2LeftSegments ?? base.row2LeftSegments,
    row2RightSegments: userConfig?.row2RightSegments ?? base.row2RightSegments,
  };
}

export function getEffectiveConfig(): FooterEffectiveConfig {
  const userConfig = loadUserConfig();
  const rows = resolveRows(userConfig);

  return {
    ...rows,
    contextWarning: clampPercent(userConfig?.contextWarning, DEFAULT_CONTEXT_WARNING),
    contextDanger: clampPercent(userConfig?.contextDanger, DEFAULT_CONTEXT_DANGER),
    colors: userConfig?.colors ?? getDefaultColors(),
    segmentOptions: {
      ...DEFAULT_SEGMENT_OPTIONS,
      ...userConfig?.segmentOptions,
      path: {
        ...DEFAULT_SEGMENT_OPTIONS.path,
        ...userConfig?.segmentOptions?.path,
      },
      git: {
        ...DEFAULT_SEGMENT_OPTIONS.git,
        ...userConfig?.segmentOptions?.git,
      },
      contextBar: {
        ...userConfig?.segmentOptions?.contextBar,
      },
    },
    icons: userConfig?.icons ?? {},
  };
}

/** Type-only re-export helpers for callers that still import ColorScheme here. */
export type { ColorScheme, IconSet };
