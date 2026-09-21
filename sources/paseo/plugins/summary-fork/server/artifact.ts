import { mkdir, readdir, rm, stat, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { PluginServerContext } from "@getpaseo/plugin/server";
import { HANDOFF_TTL_MS, saveHandoff } from "../shared/handoff-artifact.js";
import { forkSettings } from "../shared/summary-fork.js";

/** ~/.paseo/handoffs/<id>.md — managed by the daemon user, cleaned at most
 * once per plugin (re)start and lazily on every save. */
function handoffDirectory(): string {
  return join(homedir(), ".paseo", "handoffs");
}

function sanitize(value: string): string {
  return value.replace(/[^a-zA-Z0-9._-]+/g, "-").slice(0, 80) || "handover";
}

async function cleanupOld(retentionMs = HANDOFF_TTL_MS): Promise<void> {
  let entries: Array<{ name: string }>;
  try {
    entries = await readdir(handoffDirectory(), { withFileTypes: true });
  } catch {
    return; // dir missing — nothing to clean
  }
  const now = Date.now();
  for (const entry of entries) {
    const full = join(handoffDirectory(), entry.name);
    try {
      const info = await stat(full);
      if (!info.isFile() || now - info.mtimeMs <= retentionMs) continue;
      await rm(full);
    } catch {
      // best-effort cleanup; never block a save
    }
  }
}

export default function contribute(server: PluginServerContext) {
  server.registerSettings(forkSettings);

  server.handle(saveHandoff, async (input: unknown, _ctx: unknown) => {
    const { text, sourceTitle } = (input ?? {}) as { text?: string; sourceTitle?: string };
    const body = String(text ?? "");
    const dir = handoffDirectory();
    await mkdir(dir, { recursive: true });
    const now = new Date();
    const id = `${now.toISOString().replace(/[:.]/g, "-")}_${Math.random().toString(36).slice(2, 8)}`;
    const safeTitle = sanitize(String(sourceTitle ?? ""));
    const path = join(dir, `${id}_${safeTitle}.md`);
    await writeFile(path, body, "utf8");
    // Lazily prune older artifacts; never let cleanup failure fail the save.
    void cleanupOld().catch(() => undefined);
    return { path, id };
  });

  void cleanupOld().catch(() => undefined);

  return () => {};
}
