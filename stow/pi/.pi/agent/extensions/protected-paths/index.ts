/**
 * Protected Paths Extension
 *
 * Blocks read, write, edit, and/or bash tool calls to protected paths, plus
 * environment-enumeration commands that would leak env-loader's secrets.
 *
 * Matching strategies (see config.ts for the shape):
 *
 *   Bare, no wildcard (".env", "node_modules/")
 *     → exact path-segment match at any depth.
 *
 *   Bare, with a wildcard ("*.pem", ".env.*", "secrets.*")
 *     → glob-matched against the file's basename only.
 *
 *   Absolute / home-relative ("/etc/hosts", "~/.ssh/")
 *     → resolved to a real path (symlinks followed) and startsWith-matched.
 *       For paths that do not exist yet, the nearest existing ancestor is
 *       resolved instead so a symlinked parent directory cannot be used to
 *       bypass the check.
 *
 * Coverage: read, write, edit, grep, find, fd, ls (via their `path` input),
 * bash (via command-string matching), and a generic fallback that scans
 * every string-valued input of any other tool call (MCP/context-mode/etc.)
 * for a protected absolute path.
 *
 * Config location:
 *   ~/.pi/agent/configs/protected-paths.json
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, resolve } from "node:path";
import { loadConfig, type Op, type PathEntry } from "./config.js";

// ─── Path resolution ────────────────────────────────────────────────────────

/** Resolve symlinks for existing paths; for paths that don't exist yet, walk
 * up to the nearest existing ancestor and resolve that instead, so a
 * symlinked parent directory cannot be used to escape the protected root. */
function realish(path: string): string {
  let candidate = resolve(path);
  const seen = new Set<string>();
  while (!existsSync(candidate)) {
    const parent = dirname(candidate);
    if (parent === candidate || seen.has(parent)) return resolve(path); // hit fs root or loop — give up, use plain resolve
    seen.add(parent);
    candidate = parent;
  }
  try {
    const real = realpathSync(candidate);
    const suffix = resolve(path).slice(candidate.length);
    return real + suffix;
  } catch {
    return resolve(path);
  }
}

function globToRegExp(glob: string): RegExp {
  const escaped = glob.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*").replace(/\?/g, ".");
  return new RegExp(`^${escaped}$`);
}

function basename(path: string): string {
  const parts = path.split("/");
  return parts[parts.length - 1] ?? path;
}

function matchesEntry(toolPath: string, entry: PathEntry): boolean {
  const { path: entryPath } = entry;

  if (entryPath.startsWith("/") || entryPath.startsWith("~/")) {
    const resolvedEntry = entryPath.startsWith("~/")
      ? realish(resolve(homedir(), entryPath.slice(2)))
      : realish(entryPath);
    const resolvedTool = realish(toolPath);

    const dirEntry = resolvedEntry.endsWith("/") ? resolvedEntry : resolvedEntry + "/";
    return resolvedTool === resolvedEntry || resolvedTool.startsWith(dirEntry);
  }

  if (entryPath.includes("*") || entryPath.includes("?")) {
    return globToRegExp(entryPath).test(basename(toolPath));
  }

  // Bare entry, no wildcard → exact segment match at any depth
  const segment = entryPath.replace(/\/$/, "");
  return toolPath.split("/").some((p) => p === segment);
}

function getBlockedOps(toolPath: string, paths: PathEntry[]): Op[] | null {
  for (const entry of paths) {
    if (matchesEntry(toolPath, entry)) return entry.deny;
  }
  return null;
}

// ─── Environment-enumeration blocks (bash) ──────────────────────────────────
// Blocks commands that would dump the process environment env-loader injects
// secrets into. Escape hatch: PI_ALLOW_ENV_ENUM=1.

const ENV_ENUM_PATTERNS: { name: string; re: RegExp }[] = [
  { name: "env", re: /(^|[;&|(]|\n)\s*env(\s|$|;|&|\|)/ },
  { name: "printenv", re: /\bprintenv\b/ },
  { name: "set (bare)", re: /(^|[;&|(]|\n)\s*set\s*(;|&|\||\n|$)/ },
  { name: "export -p", re: /\bexport\s+-p\b/ },
  { name: "declare -x", re: /\bdeclare\s+-x\b/ },
  { name: "/proc/*/environ", re: /\/proc\/(\d+|self)\/environ\b/ },
  { name: "ps e", re: /\bps\s+(-\w*\s+)?e\w*\b/ },
];

function matchedEnvEnum(command: string): string | null {
  if (process.env.PI_ALLOW_ENV_ENUM === "1") return null;
  for (const { name, re } of ENV_ENUM_PATTERNS) {
    if (re.test(command)) return name;
  }
  return null;
}

// ─── Extension ──────────────────────────────────────────────────────────────

const PATH_INPUT_TOOLS = new Set(["read", "write", "edit", "grep", "find", "fd", "ls", "rg"]);

function collectStrings(value: unknown, out: string[], depth = 0) {
  if (depth > 4) return;
  if (typeof value === "string") {
    out.push(value);
  } else if (Array.isArray(value)) {
    for (const v of value) collectStrings(v, out, depth + 1);
  } else if (value && typeof value === "object") {
    for (const v of Object.values(value)) collectStrings(v, out, depth + 1);
  }
}

export default function protectedPathsExtension(pi: ExtensionAPI) {
  const { paths } = loadConfig();

  const bashGuarded = paths
    .filter((e) => e.deny.includes("bash"))
    .map((e) => {
      const isAbsolute = e.path.startsWith("/") || e.path.startsWith("~/");
      return {
        entry: e,
        resolved: isAbsolute
          ? e.path.startsWith("~/")
            ? resolve(homedir(), e.path.slice(2))
            : resolve(e.path)
          : null,
        bare: isAbsolute ? null : e.path.replace(/\/$/, ""),
      };
    });

  // Absolute/home-relative entries with "read" denied, used by the generic
  // fallback scan for tools that aren't read/write/edit/grep/find/fd/ls/bash.
  const absoluteReadGuarded = paths
    .filter((e) => e.deny.includes("read") && (e.path.startsWith("/") || e.path.startsWith("~/")))
    .map((e) => ({
      entry: e,
      resolved: e.path.startsWith("~/") ? resolve(homedir(), e.path.slice(2)) : resolve(e.path),
    }));

  pi.on("tool_call", async (event, ctx) => {
    const toolName = event.toolName;

    // ── read / write / edit / grep / find / fd / ls / rg ──────────────────
    if (PATH_INPUT_TOOLS.has(toolName)) {
      const toolPath = (event.input as Record<string, unknown>).path as string | undefined;
      if (!toolPath) return undefined;

      const op: Op = toolName === "write" || toolName === "edit" ? (toolName as Op) : "read";
      const blockedOps = getBlockedOps(toolPath, paths);
      if (!blockedOps || !blockedOps.includes(op)) return undefined;

      if (ctx.hasUI) {
        ctx.ui.notify(
          `[protected-paths] Blocked ${toolName} on protected path: ${toolPath}\nEdit configs/protected-paths.json to adjust.`,
          "warning",
        );
      }
      return {
        block: true,
        reason: `[protected-paths] Path "${toolPath}" is protected (${op} denied). You can override this by editing ~/.pi/agent/configs/protected-paths.json.`,
      };
    }

    // ── bash ────────────────────────────────────────────────────────────────
    if (toolName === "bash") {
      const command = (event.input as Record<string, unknown>).command as string;

      const envHit = matchedEnvEnum(command);
      if (envHit) {
        if (ctx.hasUI) {
          ctx.ui.notify(
            `[protected-paths] Blocked environment-enumeration command (${envHit}). Set PI_ALLOW_ENV_ENUM=1 to override.`,
            "warning",
          );
        }
        return {
          block: true,
          reason: `[protected-paths] Blocked environment-enumeration command (matched "${envHit}"). env-loader injects secrets into process.env; this command could disclose them. Set PI_ALLOW_ENV_ENUM=1 to override.`,
        };
      }

      for (const { entry, resolved, bare } of bashGuarded) {
        const hit = resolved ? command.includes(resolved) || command.includes(entry.path) : command.includes(bare!);
        if (hit) {
          if (ctx.hasUI) {
            ctx.ui.notify(
              `[protected-paths] Blocked bash command referencing protected path: ${entry.path}\nEdit configs/protected-paths.json to adjust.`,
              "warning",
            );
          }
          return {
            block: true,
            reason: `[protected-paths] Bash command references protected path "${entry.path}" (bash denied). You can override this by editing ~/.pi/agent/configs/protected-paths.json.`,
          };
        }
      }
      return undefined;
    }

    // ── generic fallback: MCP / context-mode / any other tool with paths ────
    if (absoluteReadGuarded.length > 0) {
      const strings: string[] = [];
      collectStrings(event.input, strings);
      for (const s of strings) {
        for (const { entry, resolved } of absoluteReadGuarded) {
          if (s.includes(resolved) || s.includes(entry.path)) {
            if (ctx.hasUI) {
              ctx.ui.notify(
                `[protected-paths] Blocked ${toolName} referencing protected path: ${entry.path}`,
                "warning",
              );
            }
            return {
              block: true,
              reason: `[protected-paths] Tool "${toolName}" input references protected path "${entry.path}" (read denied). You can override this by editing ~/.pi/agent/configs/protected-paths.json.`,
            };
          }
        }
      }
    }

    return undefined;
  });
}
