/**
 * kb-project powerbar segment
 *
 * Adds a "kb project" segment to the powerbar showing the current
 * vault slug (e.g. "hopper", "personal") next to the git branch.
 *
 * Slug resolution mirrors kb CLI logic:
 *   1. cwd inside VAULT_AI → "personal"
 *   2. basename of git repo root
 *   3. basename of cwd
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { execSync } from "child_process";
import { resolve } from "path";

const HOME = process.env.HOME ?? "~";
const VAULT_AI = process.env.VAULT_AI ?? resolve(HOME, "Vaults/Higgins/AI");

function abbreviatePath(p: string): string {
  if (p.startsWith(HOME)) return "~" + p.slice(HOME.length);
  return p;
}

function resolveSlugAndPath(cwd: string): { slug: string; path: string } {
  const abbr = abbreviatePath(cwd);

  // Rule 1: inside vault → personal
  try {
    if (resolve(cwd).startsWith(resolve(VAULT_AI))) {
      return { slug: "personal", path: abbreviatePath(VAULT_AI) };
    }
  } catch {}

  // Rule 2: git repo root
  try {
    const root = execSync("git rev-parse --show-toplevel", {
      cwd,
      timeout: 1000,
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    if (root) {
      const slug = root.split("/").pop() ?? root;
      return { slug, path: abbreviatePath(root) };
    }
  } catch {}

  // Rule 3: cwd basename
  return { slug: cwd.split("/").pop() ?? cwd, path: abbr };
}

function emitProject(pi: ExtensionAPI, ctx: ExtensionContext): void {
  const { slug, path } = resolveSlugAndPath(ctx.cwd);
  pi.events.emit("powerbar:update", {
    id: "kb-project",
    text: slug,
    suffix: path,
    icon: "◈",
    color: "accent",
  });
}

let registered = false;

export default function (pi: ExtensionAPI): void {
  pi.on("session_start", async (_event, ctx) => {
    // Register once — powerbar listener is guaranteed to be set up by session_start
    if (!registered) {
      pi.events.emit("powerbar:register-segment", {
        id: "kb-project",
        label: "KB Project",
      });
      registered = true;
    }
    emitProject(pi, ctx);
  });

  // Refresh after bash commands — user may have cd'd or switched repos
  pi.on("tool_result", async (event, ctx) => {
    if (event.toolName === "bash") {
      emitProject(pi, ctx);
    }
  });
}
