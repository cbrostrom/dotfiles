/**
 * Secret Redaction — last-line defence-in-depth.
 *
 * Three layers, in order of when they run:
 *
 *   1. tool_result — redact common secret shapes in tool output before the
 *      result reaches the model (protected-paths and env-loader host-gating
 *      are the primary controls; this catches what they miss — output from
 *      unblocked commands, third-party APIs, MCP tools, etc.).
 *
 *   2. context — before EVERY LLM call, scrub the whole model-visible
 *      conversation. This is the mechanical fix for re-emission: once a
 *      secret has entered context through any leak channel (a read of a file
 *      we do not block, an unscrubbed tool, an older session), the model can
 *      no longer see or repeat it in later turns. The on-disk transcript
 *      keeps the original; only the model-visible projection is redacted.
 *
 *   3. message_end — final belt-and-braces pass over the assistant's own
 *      finalized message, catching anything the earlier layers missed.
 *
 * This is NOT proof that no secret escaped. It is a bounded regex pass over
 * text content. If a leak is found, the on-disk session transcript still
 * contains the original — rotate the credential and start a fresh session.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

interface Redaction {
	name: string;
	re: RegExp;
	replace: (match: string) => string;
}

const REDACTIONS: Redaction[] = [
	{
		name: "PEM private key",
		re: /-----BEGIN[ A-Z]*PRIVATE KEY-----[\s\S]*?-----END[ A-Z]*PRIVATE KEY-----/g,
		replace: () => "[REDACTED:pem-private-key]",
	},
	{
		name: "Bearer/Basic auth header",
		re: /\b(Bearer|Basic)\s+[A-Za-z0-9\-_.~+/]{12,}=*/g,
		replace: (m) => `${m.split(/\s+/, 1)[0]} [REDACTED:auth-token]`,
	},
	{
		name: "GitHub token",
		re: /\bgh[oprsu]_[A-Za-z0-9]{20,}\b/g,
		replace: () => "[REDACTED:github-token]",
	},
	{
		name: "Slack token",
		re: /\bxox[baprs]-[A-Za-z0-9-]{10,}\b/g,
		replace: () => "[REDACTED:slack-token]",
	},
	{
		name: "AWS access key",
		re: /\bAKIA[0-9A-Z]{16}\b/g,
		replace: () => "[REDACTED:aws-access-key]",
	},
	{
		name: "Google API key",
		re: /\bAIza[0-9A-Za-z_-]{35,}\b/g,
		replace: () => "[REDACTED:google-api-key]",
	},
	{
		name: "OpenAI/Anthropic-style secret key",
		re: /\bsk-(ant-|proj-)?[A-Za-z0-9_-]{20,}\b/g,
		replace: () => "[REDACTED:api-key]",
	},
	{
		name: "JWT",
		re: /\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}/g,
		replace: () => "[REDACTED:jwt]",
	},
	{
		name: "password/secret/token assignment",
		re: /\b(password|secret|api[_-]?key|access[_-]?token|refresh[_-]?token)\s*[:=]\s*["']?[A-Za-z0-9_\-./+]{10,}["']?/gi,
		replace: (m) => `${m.split(/[:=]/, 1)[0]}=[REDACTED:assignment]`,
	},
	{
		// Shorter/informal spellings the assignment regex above is too strict
		// for: "password=xtS2", "passwd: hunter2", "pwd = hunter2". Fires on
		// a value of 6+ chars so common English words after "pwd"/"pass"
		// (e.g. "pwd = home") are mostly below the bar; accepts that trade-off.
		name: "password (informal assignment)",
		re: /\b(pass(word|wd)?|pwd)\s*[:=]\s*["']?[A-Za-z0-9_\-./+!@#$%^&*]{6,}["']?/gi,
		replace: (m) => `${m.split(/[:=]/, 1)[0].trim()}=[REDACTED:assignment]`,
	},
];

export function redactText(text: string): { text: string; hits: string[] } {
	const hits: string[] = [];
	let out = text;
	for (const { name, re, replace } of REDACTIONS) {
		let matched = false;
		out = out.replace(re, (m) => {
			matched = true;
			return replace(m);
		});
		if (matched) hits.push(name);
	}
	return { text: out, hits };
}

/** Keys whose string values are opaque binary/encoded payloads — never worth
 * regexing (huge, and secrets do not hide there in a useful shape). */
const SKIP_KEYS = new Set(["data", "image", "base64"]);

/** Max string length we are willing to regex per value. Secrets appear in
 * notes/output text, not megabyte blobs. */
const MAX_STRING_LEN = 200_000;

interface WalkResult {
	changed: boolean;
	hits: Set<string>;
}

/** Recursively redact string values inside an arbitrary message-like object.
 * Mutates in place; returns whether anything changed. */
function scrubObject(obj: unknown, result: WalkResult): void {
	if (obj === null || typeof obj !== "object") return;
	if (Array.isArray(obj)) {
		for (const item of obj) scrubObject(item, result);
		return;
	}
	const record = obj as Record<string, unknown>;
	for (const key of Object.keys(record)) {
		if (SKIP_KEYS.has(key)) continue;
		const value = record[key];
		if (typeof value === "string") {
			if (value.length > MAX_STRING_LEN) continue;
			const { text, hits } = redactText(value);
			if (hits.length > 0) {
				record[key] = text;
				result.changed = true;
				for (const h of hits) result.hits.add(h);
			}
		} else if (value !== null && typeof value === "object") {
			scrubObject(value, result);
		}
	}
}

export interface ScrubbedMessages {
	messages: unknown[];
	changed: boolean;
	hits: string[];
}

/** Redact secret shapes across a full AgentMessage[] (the `context` event
 * payload). Returns a new result object; messages are mutated in place. */
export function scrubAgentMessages(messages: unknown[]): ScrubbedMessages {
	const result: WalkResult = { changed: false, hits: new Set() };
	for (const message of messages) scrubObject(message, result);
	return {
		messages,
		changed: result.changed,
		hits: [...result.hits],
	};
}

export default function secretRedactionExtension(pi: ExtensionAPI) {
	// Notify at most once per session per hit-name so every LLM call does not
	// spam the UI for a secret that is already redacted in context.
	const notifiedHits = new Set<string>();

	function maybeNotify(
		ctx: { hasUI: boolean; ui: { notify: (message: string, type?: "error" | "info" | "warning") => void } },
		where: string,
		hits: string[],
	) {
		if (!ctx.hasUI) return;
		const fresh = hits.filter((h) => !notifiedHits.has(h));
		if (fresh.length === 0) return;
		for (const h of fresh) notifiedHits.add(h);
		ctx.ui.notify(
			`[secret-redaction] Redacted ${fresh.join(", ")} in ${where}. If a real credential leaked, rotate it — the on-disk transcript keeps the original.`,
			"warning",
		);
	}

	// Layer 1: tool results before they reach the model.
	pi.on("tool_result", async (event, ctx) => {
		const content = event.content as unknown;
		if (!Array.isArray(content)) return undefined;

		let changed = false;
		const allHits = new Set<string>();

		const nextContent = content.map((part) => {
			if (part && typeof part === "object" && "text" in part && typeof (part as { text: unknown }).text === "string") {
				const { text, hits } = redactText((part as { text: string }).text);
				if (hits.length > 0) {
					changed = true;
					for (const h of hits) allHits.add(h);
					return { ...(part as Record<string, unknown>), text };
				}
			}
			return part;
		});

		if (!changed) return undefined;

		maybeNotify(ctx, `${event.toolName} output`, [...allHits]);
		return { content: nextContent };
	});

	// Layer 2: the whole model-visible conversation before every LLM call.
	// This is the re-emission guard: a secret already in context (from any
	// past leak channel) becomes invisible to the model going forward.
	pi.on("context", async (event, ctx) => {
		try {
			const { changed, hits } = scrubAgentMessages(event.messages as unknown[]);
			if (!changed) return undefined;
			maybeNotify(ctx, "conversation context", hits);
			return { messages: event.messages };
		} catch (error) {
			// Fail open: a redaction bug must never brick the session.
			console.error("[secret-redaction] context scrub failed:", error);
			return undefined;
		}
	});

	// Layer 3: the assistant's own finalized message.
	pi.on("message_end", async (event, ctx) => {
		try {
			const result: WalkResult = { changed: false, hits: new Set() };
			scrubObject(event.message, result);
			if (!result.changed) return undefined;
			maybeNotify(ctx, "assistant message", [...result.hits]);
			return { message: event.message };
		} catch (error) {
			console.error("[secret-redaction] message_end scrub failed:", error);
			return undefined;
		}
	});
}
