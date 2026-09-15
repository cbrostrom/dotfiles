/**
 * Secret Redaction — last-line defence-in-depth.
 *
 * Before a tool result reaches the model, redact common secret shapes that
 * should never have been in the output in the first place (protected-paths
 * and env-loader host-gating are the primary controls; this catches what
 * they miss — output from unblocked commands, third-party APIs, MCP tools,
 * etc.).
 *
 * This is NOT proof that no secret escaped. It is a bounded regex pass over
 * text content, applied after every tool call.
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
		name: "OpenAI/Anthropic-style secret key",
		re: /\bsk-(ant-|proj-)?[A-Za-z0-9_-]{20,}\b/g,
		replace: () => "[REDACTED:api-key]",
	},
	{
		name: "password/secret/token assignment",
		re: /\b(password|secret|api[_-]?key|access[_-]?token|refresh[_-]?token)\s*[:=]\s*["']?[A-Za-z0-9_\-./+]{10,}["']?/gi,
		replace: (m) => `${m.split(/[:=]/, 1)[0]}=[REDACTED:assignment]`,
	},
];

function redactText(text: string): { text: string; hits: string[] } {
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

export default function secretRedactionExtension(pi: ExtensionAPI) {
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

		if (ctx.hasUI) {
			ctx.ui.notify(
				`[secret-redaction] Redacted ${[...allHits].join(", ")} from ${event.toolName} output before it reached the model.`,
				"warning",
			);
		}

		return { content: nextContent };
	});
}
