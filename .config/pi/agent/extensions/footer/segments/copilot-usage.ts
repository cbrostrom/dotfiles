/**
 * Copilot premium-request quota for the custom footer rail.
 * Visible only when the live model provider is `github-copilot`.
 *
 * Polls GET /copilot_internal/user with Pi's Copilot OAuth token
 * (~/.pi/agent/auth.json). Cache TTL 60s. Bypasses HTTP(S)_PROXY
 * so inherited proxy env cannot break TLS to api.github.com.
 */
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { RenderedSegment, SegmentContext } from "../types.js";
import { color } from "./helpers.js";

const REFRESH_MS = 60_000;
const AUTH_PATH = join(homedir(), ".pi", "agent", "auth.json");
const API_URL = "https://api.github.com/copilot_internal/user";

interface QuotaSnapshot {
  percent_remaining: number;
  remaining: number;
  entitlement: number;
  overage_count: number;
  unlimited: boolean;
}

interface CopilotUser {
  quota_snapshots?: {
    premium_interactions?: QuotaSnapshot;
  };
}

type Cache =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "ok"; usedPct: number; overage: number; unlimited: boolean; fetchedAt: number }
  | { status: "noauth"; fetchedAt: number }
  | { status: "error"; fetchedAt: number };

let cache: Cache = { status: "idle" };
let inflight: Promise<void> | null = null;
let timer: ReturnType<typeof setInterval> | undefined;

function requestRender(): void {
  const fn = (globalThis as Record<string, unknown>).__footerRequestRender;
  if (typeof fn === "function") {
    (fn as () => void)();
  }
}

async function readOAuthToken(): Promise<string | null> {
  try {
    const raw = await readFile(AUTH_PATH, "utf8");
    const auth = JSON.parse(raw) as {
      "github-copilot"?: { refresh?: string; access?: string };
    };
    // pi-copilot-usage uses `refresh` with Authorization: token …
    return auth["github-copilot"]?.refresh ?? auth["github-copilot"]?.access ?? null;
  } catch {
    return null;
  }
}

/** Fetch via curl --noproxy so proxy env cannot break TLS to api.github.com. */
async function fetchCopilotUser(token: string): Promise<CopilotUser> {
  const { spawn } = await import("node:child_process");
  const out = await new Promise<string>((resolve, reject) => {
    const child = spawn(
      "curl",
      [
        "-sS",
        "--noproxy",
        "*",
        "--max-time",
        "15",
        "-H",
        `Authorization: token ${token}`,
        "-H",
        "Accept: application/vnd.github+json",
        "-H",
        "User-Agent: pi-footer-copilot-usage",
        API_URL,
      ],
      {
        env: {
          ...process.env,
          HTTP_PROXY: "",
          HTTPS_PROXY: "",
          http_proxy: "",
          https_proxy: "",
          ALL_PROXY: "",
          all_proxy: "",
        },
      },
    );
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d: Buffer) => {
      stdout += d.toString();
    });
    child.stderr.on("data", (d: Buffer) => {
      stderr += d.toString();
    });
    child.on("close", (code) => {
      if (code !== 0) reject(new Error(stderr.trim() || `curl exit ${code}`));
      else resolve(stdout);
    });
  });
  return JSON.parse(out) as CopilotUser;
}

async function refresh(): Promise<void> {
  const token = await readOAuthToken();
  if (!token) {
    cache = { status: "noauth", fetchedAt: Date.now() };
    requestRender();
    return;
  }

  try {
    const data = await fetchCopilotUser(token);
    const quota = data.quota_snapshots?.premium_interactions;
    if (!quota) {
      cache = { status: "error", fetchedAt: Date.now() };
      requestRender();
      return;
    }
    if (quota.unlimited) {
      cache = {
        status: "ok",
        usedPct: 0,
        overage: 0,
        unlimited: true,
        fetchedAt: Date.now(),
      };
      requestRender();
      return;
    }
    // percent_remaining = unused; display used % (same as pi-copilot-usage)
    const usedPct = Math.round(100 - quota.percent_remaining);
    cache = {
      status: "ok",
      usedPct,
      overage: quota.overage_count ?? 0,
      unlimited: false,
      fetchedAt: Date.now(),
    };
    requestRender();
  } catch {
    cache = { status: "error", fetchedAt: Date.now() };
    requestRender();
  }
}

function isStale(force: boolean): boolean {
  if (force || cache.status === "idle") return true;
  if (cache.status === "loading") return false;
  return Date.now() - cache.fetchedAt > REFRESH_MS;
}

/** Kick a background refresh when cache is idle/stale. */
export function ensureCopilotUsageFresh(force = false): void {
  if (!isStale(force) || inflight) return;
  if (cache.status === "idle") {
    cache = { status: "loading" };
  }
  inflight = refresh().finally(() => {
    inflight = null;
  });
}

export function startCopilotUsagePolling(): void {
  ensureCopilotUsageFresh(true);
  if (timer) clearInterval(timer);
  timer = setInterval(() => ensureCopilotUsageFresh(true), REFRESH_MS);
  // Unref so the timer does not keep the process alive alone.
  timer.unref?.();
}

export function stopCopilotUsagePolling(): void {
  if (timer) clearInterval(timer);
  timer = undefined;
}

export function forceCopilotUsageRefresh(): void {
  ensureCopilotUsageFresh(true);
}

/** True when the live model bills against GitHub Copilot premium requests. */
export function isCopilotProvider(provider?: string): boolean {
  return provider === "github-copilot";
}

/**
 * Start polling only while on Copilot; stop (and stay hidden) otherwise.
 * Call from session_start / model_select with the live provider.
 */
export function syncCopilotUsagePolling(provider?: string): void {
  if (isCopilotProvider(provider)) {
    startCopilotUsagePolling();
  } else {
    stopCopilotUsagePolling();
  }
}

export const copilotUsageSegment = {
  id: "copilot_usage" as const,
  render(ctx: SegmentContext): RenderedSegment {
    // Whole segment gone unless Copilot — no placeholder on cursor/opencode.
    if (!isCopilotProvider(ctx.model?.provider)) {
      return { content: "", visible: false };
    }

    ensureCopilotUsageFresh();

    // Hide until we have real quota (no "Copilot —" for noauth/error/loading).
    if (cache.status !== "ok") {
      return { content: "", visible: false };
    }

    if (cache.unlimited) {
      return {
        content: color(ctx, "tokens", "Copilot ∞"),
        visible: true,
      };
    }

    const overage = cache.overage > 0 ? ` +${cache.overage}` : "";
    const warnMark = cache.usedPct >= 90 ? " !" : cache.usedPct >= 75 ? " ~" : "";
    const semantic =
      cache.usedPct >= 90 ? "contextError" : cache.usedPct >= 75 ? "contextWarn" : "tokens";
    const text = `Copilot ${cache.usedPct}%${overage}${warnMark}`;

    return { content: color(ctx, semantic, text), visible: true };
  },
};
