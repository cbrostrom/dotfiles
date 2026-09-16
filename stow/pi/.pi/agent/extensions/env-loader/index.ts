/**
 * env-loader — injects ~/.pi/agent/configs/.env into process.env at startup.
 *
 * Loads synchronously in the factory function so vars are available to all
 * other extensions before session_start fires. Shell environment always takes
 * precedence — existing values are never overwritten.
 *
 * Host-gated: only loads on desktop hosts (workstation / default-desktop, per
 * ~/.pi/agent/host.json). On server hosts (cloudbro, linuxbro, superbro, or
 * any other resolved slug) this is a no-op — private/server Pi should not
 * receive Slack/GitHub/cloud tokens in its main process. See the Secret
 * boundary section of the Pi+Paseo+OpenCode Go rollout plan.
 *
 * Server hosts also export PI_CAFFEINATE_DISABLED=1 here — pi-caffeinate has
 * no business on headless boxes (no ScreenSaver D-Bus service, no workable
 * sleep inhibit); its session-start inhibit failures are pure noise there.
 *
 * Config location:
 *   ~/.pi/agent/configs/.env
 *
 * Config format:
 *   SLACK_MCP_TOKEN=xoxp-...
 *   GITHUB_TOKEN=ghp-...
 *
 * Use /env to inspect loaded key names (values are never shown).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { loadEnvFile } from "./loader.js";

const DESKTOP_SLUGS = new Set(["workstation", "default-desktop"]);

function resolveHostSlug(): string {
	if (process.env.PI_HOST_SLUG) return process.env.PI_HOST_SLUG;
	try {
		const raw = readFileSync(join(homedir(), ".pi", "agent", "host.json"), "utf8");
		const parsed = JSON.parse(raw) as { slug?: string };
		if (parsed.slug) return parsed.slug;
	} catch {
		// host.json absent or unreadable — fall through to safe default
	}
	return "workstation"; // unresolved host behaves like pre-hardening default
}

export default function envLoaderExtension(pi: ExtensionAPI) {
	const hostSlug = resolveHostSlug();
	const isServerHost = !DESKTOP_SLUGS.has(hostSlug);

	if (isServerHost) {
		// Set before any other extension initialises: pi-caffeinate reads
		// PI_CAFFEINATE_DISABLED at startup. Synchronous and idempotent.
		process.env.PI_CAFFEINATE_DISABLED = "1";
	}

	// Load synchronously — runs before session_start, before any other extension
	// that needs these vars (e.g. mcp) tries to use them. Skipped entirely on
	// server hosts.
	const result = isServerHost ? { keys: [], skipped: 0, ignored: 0 } : loadEnvFile();

	if (isServerHost) {
		pi.on("session_start", async (_event, ctx) => {
			ctx.ui.notify(
				`env-loader: skipped on host "${hostSlug}" (server hosts never load ~/.pi/agent/configs/.env into process.env).`,
				"info",
			);
		});
	}

	// Surface file read errors as a notification once the UI is ready.
	if ("error" in result && result.error) {
		pi.on("session_start", async (_event, ctx) => {
			ctx.ui.notify(`env-loader: ${result.error}`, "error");
		});
	}

	// ─── /env command ─────────────────────────────────────────────────────────

	pi.registerCommand("env", {
		description: "Show env vars loaded from .env (key names only — no values)",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;

			if (isServerHost) {
				ctx.ui.notify(
					`env-loader is disabled on host "${hostSlug}". Set PI_HOST_SLUG=workstation to override locally (not recommended on shared/server machines).`,
					"info",
				);
				return;
			}

			if ("error" in result && result.error) {
				ctx.ui.notify(`env-loader: ${result.error}`, "error");
				return;
			}

			if (result.keys.length === 0 && result.skipped === 0 && result.ignored === 0) {
				ctx.ui.notify(
					"No .env found at ~/.pi/agent/configs/.env\n" +
						"Copy .env.example from the env-loader extension to get started.",
					"info",
				);
				return;
			}

			const lines: string[] = [];

			if (result.keys.length > 0) {
				lines.push(`${result.keys.length} var(s) loaded from .env:`);
				for (const key of result.keys) lines.push(`  ${key}`);
			}

			if (result.skipped > 0) {
				lines.push(`${result.skipped} approved var(s) skipped (already set in shell env)`);
			}

			if (result.ignored > 0) {
				lines.push(`${result.ignored} unapproved var(s) ignored (values not loaded)`);
			}

			ctx.ui.notify(lines.join("\n"), "info");
		},
	});
}
