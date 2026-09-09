import type { ExtensionAPI, ReadonlyFooterDataProvider, Theme, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import { visibleWidth, truncateToWidth } from "@earendil-works/pi-tui";
import type { TUI } from "@earendil-works/pi-tui";

import type {
  ActivitySnapshot,
  FooterPreset,
  SegmentContext,
  StatusLineSegmentId,
  UsageStats,
  SessionEvent,
  ThinkingLevelEvent,
  AssistantMessageEvent,
  ToolResultEvent,
  UserBashEvent,
} from "./types.js";
import { renderSegment } from "./segments/index.js";
import { getGitStatus, invalidateGitStatus, invalidateGitBranch } from "./git-status.js";
import {
  forceCopilotUsageRefresh,
  isCopilotProvider,
  stopCopilotUsagePolling,
  syncCopilotUsagePolling,
} from "./segments/copilot-usage.js";
import {
  DEFAULT_CONTEXT_DANGER,
  DEFAULT_CONTEXT_WARNING,
  getEffectiveConfig,
  saveUserConfigPatch,
} from "./config.js";
import { getIcons } from "./icons.js";
import { getDefaultColors, fg } from "./theme.js";

const GIT_BRANCH_PATTERNS: RegExp[] = [
  /\bgit\s+(checkout|switch|branch\s+-[dDmM]|merge|rebase|pull|reset|worktree)/,
  /\bgit\s+stash\s+(pop|apply)/,
];

const NAMED_PRESETS = ["editorial", "minimal", "classic"] as const;

// ═══════════════════════════════════════════════════════════════════════════
// Status Line Builder
// ═══════════════════════════════════════════════════════════════════════════

/** Render a single segment and return its content with width */
function renderSegmentWithWidth(
  segId: StatusLineSegmentId,
  ctx: SegmentContext
): { content: string; width: number; visible: boolean; isSeparator: boolean } {
  const rendered = renderSegment(segId, ctx);
  if (!rendered.visible || !rendered.content) {
    return { content: "", width: 0, visible: false, isSeparator: segId === "separator" };
  }
  return {
    content: rendered.content,
    width: visibleWidth(rendered.content),
    visible: true,
    isSeparator: segId === "separator",
  };
}

/**
 * Drop invisible segments, then collapse orphan separators so gated
 * segments (copilot_usage, plan_mode, …) do not leave `│ │` gaps.
 */
function collectVisibleParts(
  ctx: SegmentContext,
  segmentIds: StatusLineSegmentId[],
): string[] {
  const raw: { content: string; isSeparator: boolean }[] = [];
  for (const segId of segmentIds) {
    const { content, visible, isSeparator } = renderSegmentWithWidth(segId, ctx);
    if (visible) {
      raw.push({ content, isSeparator });
    }
  }
  const collapsed: { content: string; isSeparator: boolean }[] = [];
  for (const part of raw) {
    if (part.isSeparator && collapsed.length === 0) continue; // leading
    if (part.isSeparator && collapsed[collapsed.length - 1]?.isSeparator) continue; // double
    collapsed.push(part);
  }
  while (collapsed.length > 0 && collapsed[collapsed.length - 1]?.isSeparator) {
    collapsed.pop(); // trailing
  }
  return collapsed.map((p) => p.content);
}

/**
 * Build footer content from left and right segments.
 * Left segments are left-aligned, right segments are right-aligned.
 */
function buildFooterContent(
  ctx: SegmentContext,
  leftSegments: StatusLineSegmentId[],
  rightSegments: StatusLineSegmentId[],
  availableWidth: number,
): string {
  const maxContentWidth = Math.max(0, availableWidth - 2);

  const leftParts = collectVisibleParts(ctx, leftSegments);

  const rightParts = collectVisibleParts(ctx, rightSegments);
  let rightWidth = 0;
  for (const content of rightParts) {
    rightWidth += visibleWidth(content) + 1; // +1 for space between
  }
  if (rightParts.length > 0) {
    rightWidth -= 1; // Remove trailing space
  }

  let leftStr = leftParts.join(" ");
  let rightStr = rightParts.join(" ");

  // Handle case with no right segments
  if (rightParts.length === 0) {
    const finalLeft = truncateToWidth(leftStr, maxContentWidth);
    return " " + finalLeft + " ".repeat(Math.max(0, maxContentWidth - visibleWidth(finalLeft))) + " ";
  }

  // If right side alone is too big, just show right side
  if (rightWidth >= maxContentWidth) {
    return " " + truncateToWidth(rightStr, maxContentWidth) + " ";
  }

  // Ensure at least 1 space between left and right
  const maxLeftWidth = maxContentWidth - rightWidth - 1;
  const finalLeft = truncateToWidth(leftStr, Math.max(0, maxLeftWidth));
  const finalLeftWidth = visibleWidth(finalLeft);

  const padding = maxContentWidth - finalLeftWidth - rightWidth;

  const result = " " + finalLeft + " ".repeat(padding) + rightStr + " ";
  return truncateToWidth(result, availableWidth);
}

function parseWarnDanger(args: string): { warning?: number; danger?: number } | undefined {
  const parts = args.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return undefined;
  if (parts.length === 1) {
    const warning = Number(parts[0]);
    if (!Number.isFinite(warning)) return undefined;
    return { warning };
  }
  const warning = Number(parts[0]);
  const danger = Number(parts[1]);
  if (!Number.isFinite(warning) || !Number.isFinite(danger)) return undefined;
  return { warning, danger };
}

// ═══════════════════════════════════════════════════════════════════════════
// Extension
// ═══════════════════════════════════════════════════════════════════════════

export default function footer(pi: ExtensionAPI) {
  let sessionStartTime = Date.now();
  let currentCtx: ExtensionContext | null = null;
  let footerDataRef: ReadonlyFooterDataProvider | null = null;
  let lastBranchLength = 0;
  let cachedUsageStats: UsageStats | null = null;
  let tuiRef: TUI | null = null;
  let activity: ActivitySnapshot = { state: "ready" };
  let activeToolCount = 0;

  const bumpActivity = (next: ActivitySnapshot) => {
    activity = next;
    tuiRef?.requestRender();
  };

  // Track session start
  pi.on("session_start", async (_event: unknown, ctx: ExtensionContext) => {
    sessionStartTime = Date.now();
    currentCtx = ctx;
    lastBranchLength = 0;
    cachedUsageStats = null;
    activity = { state: "ready" };
    activeToolCount = 0;

    if (ctx.hasUI) {
      setupFooter(ctx);
      // Poll only while the live model is Copilot (hidden otherwise).
      syncCopilotUsagePolling(resolveLiveModel(ctx)?.provider);
    }
  });

  pi.on("session_shutdown", async () => {
    stopCopilotUsagePolling();
  });

  pi.on("agent_start", async () => {
    activeToolCount = 0;
    bumpActivity({ state: "working" });
  });

  pi.on("agent_settled", async () => {
    activeToolCount = 0;
    bumpActivity({ state: "ready" });
  });

  pi.on("tool_execution_start", async (event: { toolName?: string }) => {
    activeToolCount += 1;
    bumpActivity({
      state: "working",
      toolName: typeof event.toolName === "string" ? event.toolName : undefined,
    });
  });

  pi.on("tool_execution_end", async () => {
    activeToolCount = Math.max(0, activeToolCount - 1);
    if (activeToolCount === 0) {
      bumpActivity({ state: "working" });
    }
  });

  // Invalidate git status on file changes
  pi.on("tool_result", async (event: ToolResultEvent, _ctx: ExtensionContext) => {
    if (event.toolName === "write" || event.toolName === "edit") {
      invalidateGitStatus();
    }
    if (event.toolName === "bash" && event.input?.command) {
      const cmd = String(event.input.command);
      if (GIT_BRANCH_PATTERNS.some(p => p.test(cmd))) {
        invalidateGitStatus();
        invalidateGitBranch();
        setTimeout(() => tuiRef?.requestRender(), 100);
      }
    }
  });

  // Also catch user escape commands (! prefix)
  pi.on("user_bash", async (event: UserBashEvent, _ctx: ExtensionContext) => {
    if (GIT_BRANCH_PATTERNS.some(p => p.test(event.command))) {
      invalidateGitStatus();
      invalidateGitBranch();
      tuiRef?.requestRender();
    }
  });

  // Ctrl+P cycles a session-start scoped snapshot whose `name` can lag
  // modelOverrides; re-render so the model segment can read the live registry.
  pi.on("model_select", async (_event: unknown, ctx: ExtensionContext) => {
    syncCopilotUsagePolling(resolveLiveModel(ctx)?.provider);
    tuiRef?.requestRender();
  });

  pi.registerCommand("copilot-usage", {
    description: "Refresh Copilot premium-request % in the footer rail",
    handler: async (_args, ctx) => {
      if (!isCopilotProvider(resolveLiveModel(ctx)?.provider)) {
        ctx.ui.notify("Copilot usage only shows on github-copilot models", "info");
        return;
      }
      forceCopilotUsageRefresh();
      tuiRef?.requestRender();
      ctx.ui.notify("Refreshing Copilot usage…", "info");
    },
  });

  pi.registerCommand("rail", {
    description: "Footer rail: /rail [status|editorial|minimal|classic|warn <n> [danger]]",
    getArgumentCompletions: (prefix: string) => {
      const items = [
        { value: "status", label: "status" },
        { value: "editorial", label: "editorial" },
        { value: "minimal", label: "minimal" },
        { value: "classic", label: "classic" },
        { value: "warn", label: "warn <pct> [danger]" },
      ];
      const filtered = items.filter((i) => i.value.startsWith(prefix.trim()));
      return filtered.length > 0 ? filtered : null;
    },
    handler: async (args, ctx) => {
      const raw = (args ?? "").trim();
      const [head, ...rest] = raw.split(/\s+/).filter(Boolean);
      const cfg = getEffectiveConfig();

      if (!head || head === "status") {
        ctx.ui.notify(
          [
            `preset: ${cfg.preset}`,
            `context warn/danger: ${cfg.contextWarning}/${cfg.contextDanger}`,
            `activity: ${activity.state}${activity.toolName ? ` (${activity.toolName})` : ""}`,
          ].join(" · "),
          "info",
        );
        return;
      }

      if ((NAMED_PRESETS as readonly string[]).includes(head)) {
        const preset = head as Exclude<FooterPreset, "custom">;
        saveUserConfigPatch({ preset });
        tuiRef?.requestRender();
        ctx.ui.notify(`Rail preset: ${preset}`, "info");
        return;
      }

      if (head === "warn" || head === "threshold" || head === "thresholds") {
        const parsed = parseWarnDanger(rest.join(" "));
        if (!parsed) {
          ctx.ui.notify(
            `Usage: /rail warn <warning> [danger]  (current ${cfg.contextWarning}/${cfg.contextDanger})`,
            "warning",
          );
          return;
        }
        const warning = parsed.warning ?? cfg.contextWarning;
        const danger = parsed.danger ?? Math.max(warning, cfg.contextDanger);
        if (danger < warning) {
          ctx.ui.notify("danger must be >= warning", "error");
          return;
        }
        saveUserConfigPatch({ contextWarning: warning, contextDanger: danger });
        tuiRef?.requestRender();
        ctx.ui.notify(`Context thresholds: warn ${warning}% / danger ${danger}%`, "info");
        return;
      }

      ctx.ui.notify(
        `Unknown /rail arg. Try: status | ${NAMED_PRESETS.join(" | ")} | warn <n> [danger]`,
        "warning",
      );
    },
  });

  /**
   * Ctrl+P applies `_scopedModels` objects snapshotted at session start.
   * `/model` picks from the live registry (where `modelOverrides.name` lands).
   * Prefer the registry copy so the footer shows the override after cycling.
   */
  function resolveLiveModel(ctx: ExtensionContext) {
    const sessionModel = ctx.model;
    if (!sessionModel) return undefined;
    return ctx.modelRegistry?.find?.(sessionModel.provider, sessionModel.id) ?? sessionModel;
  }

  function buildSegmentContext(ctx: ExtensionContext, width: number, theme: Theme): SegmentContext {
    const effectiveConfig = getEffectiveConfig();
    const colors = effectiveConfig.colors ?? getDefaultColors();
    const model = resolveLiveModel(ctx);

    const branch = (ctx.sessionManager?.getBranch?.() ?? []) as SessionEvent[];
    const branchLen = branch.length;

    const isAssistantMessageEvent = (e: SessionEvent): e is AssistantMessageEvent =>
      e.type === "message" && (e as AssistantMessageEvent).message.role === "assistant";
    const completedMessages = branch
      .filter(isAssistantMessageEvent)
      .map(e => e.message as AssistantMessage)
      .filter(m => m.stopReason !== "error" && m.stopReason !== "aborted");

    // Cache usageStats — only recompute when branch grows
    let usageStats: UsageStats;
    if (cachedUsageStats && branchLen === lastBranchLength) {
      usageStats = cachedUsageStats;
    } else {
      usageStats = completedMessages.reduce<UsageStats>(
        (acc, m) => ({
          input: acc.input + m.usage.input,
          output: acc.output + m.usage.output,
          cacheRead: acc.cacheRead + m.usage.cacheRead,
          cacheWrite: acc.cacheWrite + m.usage.cacheWrite,
          cost: acc.cost + m.usage.cost.total,
        }),
        { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0 },
      );
      cachedUsageStats = usageStats;
      lastBranchLength = branchLen;
    }

    const isThinkingEvent = (e: SessionEvent): e is ThinkingLevelEvent =>
      e.type === "thinking_level_change";
    const thinkingLevelFromSession = branch
      .filter(isThinkingEvent)
      .reduce((_, e) => e.thinkingLevel ?? "off", "off");

    const lastAssistant = completedMessages.at(-1);

    // Calculate context percentage
    const contextTokens = lastAssistant
      ? lastAssistant.usage.input + lastAssistant.usage.output +
        lastAssistant.usage.cacheRead + lastAssistant.usage.cacheWrite
      : 0;
    const contextWindow = model?.contextWindow || 0;
    const contextPercent = contextWindow > 0 ? (contextTokens / contextWindow) * 100 : 0;

    // Get git status (cached)
    const gitBranch = footerDataRef?.getGitBranch() ?? null;
    const gitStatus = getGitStatus(gitBranch);

    // Check if using OAuth subscription
    const usingSubscription = model
      ? ctx.modelRegistry?.isUsingOAuth?.(model) ?? false
      : false;

    const isLocalModel = /localhost|127\.0\.0\.1|::1/.test((model as { baseUrl?: string } | undefined)?.baseUrl ?? "");

    return {
      model,
      isLocalModel,
      thinkingLevel: thinkingLevelFromSession || pi.getThinkingLevel(),
      sessionId: ctx.sessionManager?.getSessionId?.(),
      usageStats,
      contextPercent,
      contextWindow,
      contextWarning: effectiveConfig.contextWarning ?? DEFAULT_CONTEXT_WARNING,
      contextDanger: effectiveConfig.contextDanger ?? DEFAULT_CONTEXT_DANGER,
      usingSubscription,
      sessionStartTime,
      git: gitStatus,
      activity,
      options: effectiveConfig.segmentOptions ?? {},
      width,
      theme,
      colors,
      icons: getIcons(effectiveConfig.icons),
    };
  }

  function setupFooter(ctx: ExtensionContext) {
    ctx.ui.setFooter((tui: TUI, theme: Theme, footerData: ReadonlyFooterDataProvider) => {
      footerDataRef = footerData;
      tuiRef = tui;

      // Expose a re-render trigger for out-of-turn state changes (e.g. /caveman toggle).
      (globalThis as Record<string, unknown>).__footerRequestRender = () => tui.requestRender();

      // Subscribe to branch changes for re-render
      const unsub = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          if (!currentCtx) return [];

          const effectiveConfig = getEffectiveConfig();
          let segmentCtx;
          try {
            segmentCtx = buildSegmentContext(currentCtx, width, theme);
          } catch {
            return [];
          }

          const row1 = buildFooterContent(
            segmentCtx,
            effectiveConfig.row1LeftSegments,
            effectiveConfig.row1RightSegments,
            width,
          );
          const row2 = buildFooterContent(
            segmentCtx,
            effectiveConfig.row2LeftSegments,
            effectiveConfig.row2RightSegments,
            width,
          );

          const divider = fg(theme, "separator", "─".repeat(width), segmentCtx.colors);

          return ["", row1, divider, row2];
        },
      };
    });
  }
}
