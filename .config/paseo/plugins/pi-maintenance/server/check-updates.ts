import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import type { RpcInput } from "@getpaseo/plugin";
import { checkUpdates, type UpdateItem, type UpdateStatus } from "../shared/updates.js";

const exec = promisify(execFile);
const CACHE_TTL_MS = 24 * 60 * 60 * 1_000;
const PI_AGENT_DIR = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
const NPM_ROOT = join(PI_AGENT_DIR, "npm");
const SETTINGS_PATH = join(PI_AGENT_DIR, "settings.json");

let cachedStatus: UpdateStatus | undefined;
let cachedAt = 0;
let inFlight: Promise<UpdateStatus> | undefined;

type PackageSetting = string | { source?: string };
type OutdatedEntry = { current?: string; latest?: string };

function sourceOf(setting: PackageSetting): string {
  return typeof setting === "string" ? setting : (setting.source ?? "");
}

function npmPackageName(source: string): string | undefined {
  if (!source.startsWith("npm:")) return undefined;
  const spec = source.slice(4);
  if (!spec) return undefined;
  if (!spec.startsWith("@")) return spec.split("@")[0] || undefined;
  const slash = spec.indexOf("/");
  if (slash === -1) return undefined;
  const versionAt = spec.indexOf("@", slash);
  return versionAt === -1 ? spec : spec.slice(0, versionAt);
}

function gitCheckout(source: string): string | undefined {
  if (!source.startsWith("git:github.com/")) return undefined;
  const repository = source.slice(4).split("@")[0];
  return repository ? join(PI_AGENT_DIR, "git", repository) : undefined;
}

async function run(command: string, args: string[], timeout = 30_000): Promise<string> {
  const { stdout } = await exec(command, args, {
    encoding: "utf8",
    timeout,
    maxBuffer: 2 * 1024 * 1024,
  });
  return stdout.trim();
}

async function readPackageSources(): Promise<string[]> {
  const settings = JSON.parse(await readFile(SETTINGS_PATH, "utf8")) as {
    packages?: PackageSetting[];
  };
  return (settings.packages ?? []).map(sourceOf).filter(Boolean);
}

async function checkPiCore(): Promise<UpdateItem | undefined> {
  const [current, latestJson] = await Promise.all([
    run("pi", ["--version"], 10_000),
    run("npm", ["view", "@earendil-works/pi-coding-agent", "version", "--json"]),
  ]);
  const latest = String(JSON.parse(latestJson));
  if (!current || !latest || current === latest) return undefined;
  return { id: "pi", label: "Pi", current, latest, source: "pi" };
}

async function checkNpmPackages(sources: string[]): Promise<UpdateItem[]> {
  const names = [...new Set(sources.map(npmPackageName).filter((name): name is string => Boolean(name)))];
  if (names.length === 0) return [];

  let stdout = "";
  try {
    stdout = await run("npm", ["outdated", "--json", "--prefix", NPM_ROOT, ...names]);
  } catch (error) {
    const failed = error as Error & { stdout?: string };
    if (!failed.stdout) throw error;
    stdout = failed.stdout.trim();
  }
  if (!stdout) return [];

  const outdated = JSON.parse(stdout) as Record<string, OutdatedEntry>;
  return Object.entries(outdated).flatMap(([name, entry]) => {
    if (!entry.current || !entry.latest || entry.current === entry.latest) return [];
    return [{ id: `npm:${name}`, label: name, current: entry.current, latest: entry.latest, source: "npm" as const }];
  });
}

async function checkGitPackage(source: string): Promise<UpdateItem | undefined> {
  const checkout = gitCheckout(source);
  if (!checkout) return undefined;
  const [current, remote, packageText] = await Promise.all([
    run("git", ["-C", checkout, "rev-parse", "HEAD"], 10_000),
    run("git", ["-C", checkout, "ls-remote", "origin", "HEAD"], 20_000),
    readFile(join(checkout, "package.json"), "utf8"),
  ]);
  const latest = remote.split(/\s+/)[0] ?? "";
  if (!current || !latest || current === latest) return undefined;
  const pkg = JSON.parse(packageText) as { name?: string };
  return {
    id: source,
    label: pkg.name ?? source.slice(4),
    current: current.slice(0, 8),
    latest: latest.slice(0, 8),
    source: "git",
  };
}

async function performCheck(): Promise<UpdateStatus> {
  const checkedAt = new Date().toISOString();
  const errors: string[] = [];
  const sources = await readPackageSources();
  const checks: Promise<UpdateItem | UpdateItem[] | undefined>[] = [
    checkPiCore().catch((error) => {
      errors.push(`Pi: ${error instanceof Error ? error.message : String(error)}`);
      return undefined;
    }),
    checkNpmPackages(sources).catch((error) => {
      errors.push(`npm packages: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }),
    ...sources.filter((source) => source.startsWith("git:")).map((source) =>
      checkGitPackage(source).catch((error) => {
        errors.push(`${source}: ${error instanceof Error ? error.message : String(error)}`);
        return undefined;
      }),
    ),
  ];

  const results = await Promise.all(checks);
  const updates = results.flatMap((result) => result ?? []);
  return { checkedAt, cached: false, updates, errors };
}

export async function handleCheckUpdates({ force }: RpcInput<typeof checkUpdates>): Promise<UpdateStatus> {
  if (!force && cachedStatus && Date.now() - cachedAt < CACHE_TTL_MS) {
    return { ...cachedStatus, cached: true };
  }
  if (!force && inFlight) return inFlight;

  inFlight = performCheck().then((status) => {
    cachedStatus = status;
    cachedAt = Date.now();
    return status;
  }).finally(() => {
    inFlight = undefined;
  });
  return inFlight;
}
