/**
 * Config loader for the protected-paths extension.
 *
 * Reads ~/.pi/agent/configs/protected-paths.json if present.
 * Falls back to built-in defaults when the file is absent or unreadable.
 *
 * Config shape:
 * {
 *   "paths": [
 *     { "path": ".env",                         "deny": ["read", "write", "edit", "bash"] },
 *     { "path": "*.pem",                        "deny": ["read", "write", "edit", "bash"] },
 *     { "path": ".git/",                        "deny": ["read", "write", "edit"] },
 *     { "path": "node_modules/",                "deny": ["write", "edit"] },
 *     { "path": "~/.pi/agent/auth.json",        "deny": ["read", "write", "edit", "bash"] },
 *   ]
 * }
 *
 * Matching:
 *   - Absolute / home-relative ("/etc/hosts", "~/.ssh/") → prefix match after
 *     resolving symlinks (see index.ts).
 *   - Bare, no wildcard (".env", "node_modules/") → exact path-segment match
 *     at any depth.
 *   - Bare, with a wildcard ("*.pem", ".env.*", "secrets.*") → glob-matched
 *     against the file's basename only.
 *
 * deny is a denylist — the listed operations are blocked for that path.
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export type Op = "read" | "write" | "edit" | "bash";

export interface PathEntry {
  path: string;
  deny: Op[];
}

export interface ProtectedPathsConfig {
  paths: PathEntry[];
}

export const DEFAULT_PATHS: PathEntry[] = [
  { path: ".env", deny: ["read", "write", "edit", "bash"] },
  { path: ".env.*", deny: ["read", "write", "edit", "bash"] },
  { path: "*.pem", deny: ["read", "write", "edit", "bash"] },
  { path: "*.key", deny: ["read", "write", "edit", "bash"] },
  { path: "*.p12", deny: ["read", "write", "edit", "bash"] },
  { path: "*.pfx", deny: ["read", "write", "edit", "bash"] },
  { path: ".netrc", deny: ["read", "write", "edit", "bash"] },
  { path: ".npmrc", deny: ["read", "write", "edit", "bash"] },
  { path: ".pypirc", deny: ["read", "write", "edit", "bash"] },
  { path: ".git-credentials", deny: ["read", "write", "edit", "bash"] },
  { path: "secrets.*", deny: ["read", "write", "edit", "bash"] },
  { path: "credentials.*", deny: ["read", "write", "edit", "bash"] },
  { path: "id_rsa", deny: ["read", "write", "edit", "bash"] },
  { path: "id_ed25519", deny: ["read", "write", "edit", "bash"] },
  { path: ".git/", deny: ["read", "write", "edit"] },
  { path: "node_modules/", deny: ["write", "edit"] },
  { path: "~/.pi/agent/auth.json", deny: ["read", "write", "edit", "bash"] },
  { path: "~/.pi/agent/configs/.env", deny: ["read", "write", "edit", "bash"] },
  { path: "~/.ssh/", deny: ["read", "write", "edit", "bash"] },
  { path: "~/.aws/", deny: ["read", "write", "edit", "bash"] },
  { path: "~/.gnupg/", deny: ["read", "write", "edit", "bash"] },
  { path: "~/.kube/config", deny: ["read", "write", "edit", "bash"] },
  { path: "~/.docker/config.json", deny: ["read", "write", "edit", "bash"] },
];

const CONFIG_PATH = join(homedir(), ".pi", "agent", "configs", "protected-paths.json");

export function loadConfig(): ProtectedPathsConfig {
  try {
    const raw = readFileSync(CONFIG_PATH, "utf8");
    const parsed = JSON.parse(raw);

    const paths =
      Array.isArray(parsed.paths) && parsed.paths.length > 0
        ? (parsed.paths as PathEntry[])
        : DEFAULT_PATHS;

    return { paths };
  } catch {
    // File absent or unreadable — use defaults
    return { paths: DEFAULT_PATHS };
  }
}
