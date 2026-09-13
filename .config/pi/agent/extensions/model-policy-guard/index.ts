/**
 * Model Policy Guard
 *
 * Provider-aware, host-aware replacement for the Cursor-only model guard.
 * Reads the tracked policy at ~/.pi/agent/configs/model-policy.json (symlinked
 * from dotfiles) and enforces it on every model_select, plus a recheck at
 * session_start and before_agent_start (covers Paseo-created agents and
 * session restore, which model_select alone does not).
 *
 * enabledModels only scopes /scoped-models and Ctrl+P — it is not
 * enforcement. This extension owns the final decision for /model, CLI
 * arguments, Paseo-launched agents, and extension-driven model changes.
 *
 * Host resolution order:
 *   1. PI_HOST_SLUG env var
 *   2. ~/.pi/agent/host.json { "slug": "..." } (written by modules/pi/install.sh)
 *   3. hostname() matched against policy hosts[*].aliases
 *   4. "default-desktop"
 *
 * Config location: ~/.pi/agent/configs/model-policy.json
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync, existsSync } from "node:fs";
import { homedir, hostname } from "node:os";
import { join } from "node:path";

// ─── Types ──────────────────────────────────────────────────────────────────

interface HostPolicy {
	aliases: string[];
	groups: string[];
	defaultProvider?: string;
	defaultModel?: string;
	defaultThinkingLevel?: string;
}

interface Policy {
	defaults: { fallbackModel: string; thinking: string };
	groups: Record<string, string[]>;
	hosts: Record<string, HostPolicy>;
}

type Classification = "blocked" | "public-only" | "retained" | "conditional" | "allowed";

const POLICY_PATH = join(homedir(), ".pi", "agent", "configs", "model-policy.json");
const HOST_PATH = join(homedir(), ".pi", "agent", "host.json");

// ─── Loading ────────────────────────────────────────────────────────────────

function loadPolicy(): Policy | null {
	try {
		return JSON.parse(readFileSync(POLICY_PATH, "utf8")) as Policy;
	} catch {
		return null;
	}
}

function resolveHostSlug(policy: Policy): string {
	const envSlug = process.env.PI_HOST_SLUG;
	if (envSlug && policy.hosts[envSlug]) return envSlug;

	if (existsSync(HOST_PATH)) {
		try {
			const parsed = JSON.parse(readFileSync(HOST_PATH, "utf8")) as { slug?: string };
			if (parsed.slug && policy.hosts[parsed.slug]) return parsed.slug;
		} catch {
			// fall through
		}
	}

	const host = hostname();
	for (const [slug, hp] of Object.entries(policy.hosts)) {
		if (hp.aliases?.includes(host)) return slug;
	}

	return policy.hosts["default-desktop"] ? "default-desktop" : Object.keys(policy.hosts)[0];
}

// ─── Classification ─────────────────────────────────────────────────────────

/** Strip @context suffix. Cursor :fast/:slow suffixes are checked separately
 * and are NOT stripped here — the raw id is what the plan calls "before
 * normalizing aliases". */
function stripContext(id: string): string {
	return id.split("@")[0] ?? id;
}

function isCursorFastVariant(provider: string, rawId: string): boolean {
	if (provider !== "cursor") return false;
	return stripContext(rawId).endsWith(":fast");
}

class PolicyIndex {
	blocked = new Set<string>();
	publicOnly = new Set<string>();
	retained = new Set<string>();
	conditional = new Set<string>();
	hostAllowed = new Map<string, Set<string>>();

	constructor(policy: Policy) {
		for (const key of policy.groups.blockedTraining ?? []) this.blocked.add(key);
		for (const key of policy.groups.blockedUnknown ?? []) this.blocked.add(key);
		for (const key of policy.groups.publicFree ?? []) this.publicOnly.add(key);
		for (const key of policy.groups.goRetained ?? []) this.retained.add(key);
		for (const key of policy.groups.goConditional ?? []) this.conditional.add(key);

		for (const [slug, hp] of Object.entries(policy.hosts)) {
			const set = new Set<string>();
			for (const groupName of hp.groups) {
				for (const key of policy.groups[groupName] ?? []) set.add(key);
			}
			this.hostAllowed.set(slug, set);
		}
	}

	classify(key: string, hostSlug: string): Classification {
		if (this.blocked.has(key)) return "blocked";
		const allowed = this.hostAllowed.get(hostSlug);
		if (!allowed || !allowed.has(key)) return "blocked";
		if (this.publicOnly.has(key)) return "public-only";
		if (this.retained.has(key)) return "retained";
		if (this.conditional.has(key)) return "conditional";
		return "allowed";
	}
}

// ─── Extension ──────────────────────────────────────────────────────────────

export default function modelPolicyGuard(pi: ExtensionAPI) {
	const policy = loadPolicy();
	if (!policy) {
		// No tracked policy file — nothing to enforce. cursor-model-guard still
		// covers Cursor as a fallback until the installer lays this down.
		return;
	}

	const index = new PolicyIndex(policy);
	const hostSlug = resolveHostSlug(policy);

	let reverting = false;

	function findFallback(ctx: Parameters<Parameters<ExtensionAPI["on"]>[1]>[1]) {
		const hp = policy!.hosts[hostSlug];
		const candidates = [
			hp?.defaultModel && hp?.defaultProvider ? `${hp.defaultProvider}/${hp.defaultModel}` : undefined,
			policy!.defaults.fallbackModel,
		].filter(Boolean) as string[];

		for (const key of candidates) {
			const [provider, ...rest] = key.split("/");
			const id = rest.join("/") || provider;
			const model = ctx.modelRegistry.find(provider, id) ?? ctx.modelRegistry.find(provider, key);
			if (model) return model;
		}
		return undefined;
	}

	async function enforce(
		provider: string,
		rawId: string,
		ctx: Parameters<Parameters<ExtensionAPI["on"]>[1]>[1],
		previousModel: unknown,
	) {
		if (reverting) return;

		if (isCursorFastVariant(provider, rawId)) {
			ctx.ui.notify(
				`[model-policy-guard] Blocked ${provider}/${rawId} — Cursor :fast variants are never allowed.`,
				"error",
			);
			return revert(ctx, previousModel);
		}

		const id = stripContext(rawId);
		const key = `${provider}/${id}`;
		const cls = index.classify(key, hostSlug);

		if (cls === "blocked") {
			ctx.ui.notify(
				`[model-policy-guard] Blocked ${key} — not permitted on host "${hostSlug}". Edit model-policy.json to allow it.`,
				"error",
			);
			return revert(ctx, previousModel);
		}

		if (cls === "public-only") {
			ctx.ui.notify(
				`[model-policy-guard] ${key} is a free/training endpoint. Do not use it for private work.`,
				"warning",
			);
		} else if (cls === "retained") {
			ctx.ui.notify(
				`[model-policy-guard] ${key} retains data for abuse monitoring (up to 30 days). Not private.`,
				"warning",
			);
		} else if (cls === "conditional") {
			ctx.ui.notify(
				`[model-policy-guard] ${key} is zero-retention under a monthly-renewed agreement. Re-verify before 30-09-2026.`,
				"warning",
			);
		}
	}

	async function revert(ctx: Parameters<Parameters<ExtensionAPI["on"]>[1]>[1], previousModel: unknown) {
		const fallback = findFallback(ctx) ?? (previousModel as never);
		if (!fallback) return;
		reverting = true;
		try {
			await pi.setModel(fallback);
		} finally {
			reverting = false;
		}
	}

	pi.on("model_select", async (event, ctx) => {
		const model = event.model;
		if (!model) return;
		await enforce(model.provider, model.id, ctx, event.previousModel);
	});

	// Recheck the active model at session start (covers session restore and
	// Paseo-created agents that bypass model_select entirely).
	pi.on("session_start", async (_event, ctx) => {
		const model = ctx.model;
		if (!model) return;
		await enforce(model.provider, model.id, ctx, undefined);
	});

	// Recheck before the first agent request of each turn.
	pi.on("before_agent_start", async (_event, ctx) => {
		const model = ctx.model;
		if (!model) return;
		await enforce(model.provider, model.id, ctx, undefined);
	});
}
