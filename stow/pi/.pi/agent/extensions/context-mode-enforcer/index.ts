/**
 * context-mode-enforcer — global tool_call guard that forces large/derivable
 * output through context-mode's ctx_* tools instead of raw bash/read.
 *
 * Why this exists (not just the pi-yaml-hooks bash guard):
 * - pi-yaml-hooks' guard-context-mode hook only fires on the built-in `bash`
 *   tool. It never sees Cursor-native tool activity, which bypasses Pi's
 *   extension/tool layer entirely (see cursor-strict-mcp-only patch).
 * - Once Cursor is forced to MCP-only (that patch), every Cursor action —
 *   including bridged `bash`/`read` calls proxied through pi-cursor-sdk's
 *   local MCP bridge — arrives here as a normal Pi `tool_call` event. This
 *   extension is what actually enforces the policy on that traffic; the
 *   patch only removes Cursor's escape hatch.
 * - Runs for every model/provider Pi supports (Copilot, Anthropic, Cursor via
 *   bridge, OpenCode, ...), not just Cursor.
 *
 * Fail-open by design: if context-mode's ctx_execute tool isn't active in
 * this session (extension failed to load, disabled, etc.), this guard gets
 * out of the way rather than bricking the session. Emergency escape hatch:
 * PI_CONTEXT_ENFORCER_DISABLE=1.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const DISABLE_ENV = "PI_CONTEXT_ENFORCER_DISABLE";

// Commands that always flood context when run raw. Mirrors and extends the
// pi-yaml-hooks guard-context-mode allow/block lists so the same policy
// applies uniformly across every tool-call path (native Pi + Cursor bridge).
const BLOCK_PATTERNS: Array<{ re: RegExp; reason: string }> = [
	{
		re: /\b(cat|head|tail|less|more)\b/,
		reason: "file dump command — use ctx_execute_file to analyze instead of reading raw",
	},
	{
		re: /\bfind\b.*-type|ls\s+-R|\bgrep\s+-[a-zA-Z]*r\b/,
		reason: "recursive file/dir scan — use ctx_execute (shell) or ctx_batch_execute",
	},
	{
		re: /\b(curl|wget)\b/,
		reason: "raw HTTP fetch — use ctx_execute with fetch(), or ctx_fetch_and_index for docs",
	},
	{
		re: /\b(npm|pnpm|yarn)\s+(test|run\s+test|ls|outdated|audit)\b|\bpytest\b|\bgo\s+test\b|\bvitest\b/,
		reason: "test/build/audit runner — output can be large; use ctx_execute to capture + summarize",
	},
	{
		re: /\bgit\s+(log\s+-p|diff)\b/,
		reason: "potentially large git output — use ctx_execute to capture + summarize",
	},
	{
		re: /\bdocker\s+(ps|logs|inspect)\b|\bkubectl\s+get\b/,
		reason: "infra inspection command — use ctx_execute to capture + summarize",
	},
];

// Trivial one-liners that never flood context — let them through untouched.
const ALLOW_RE =
	/^\s*(git\s+(status|branch|diff\s+--stat|log\s+-1)|pwd|whoami|echo\s|which\s|ls(\s+-la?)?\s*$)/;

// Fast/bounded lookups that pass through before the BLOCK scan (mirrors the
// guard-context-mode escape hatch in hooks.yaml):
// - mdfind is Spotlight-backed: seconds, tiny output.
// - A chain whose output is line-capped by head/tail/wc cannot flood context.
//   NOTE: this does NOT cover recursive scans (find, grep -r, ls -R) — those
//   cap bytes written, not run time — recursive-scan denial wins below.
const FAST_ALLOW_RE = /\bmdfind\b/;
const RECURSIVE_SCAN_RE = /\b(find|ls\s+-R|tree|du)\b|\bgrep\s+-[a-zA-Z]*[rR]/;
const PIPE_CAPPED_RE = /\|\s*(head|tail|wc)\b/;

function chainedCommandCount(cmd: string): number {
	// Rough count of &&, ||, ; separators — mirrors the YAML hook's heuristic
	// for "do this as one ctx_batch_execute instead of N bash calls".
	return (cmd.match(/&&|\|\||;/g) ?? []).length;
}

function parseEnvBoolean(value: string | undefined, fallback: boolean): boolean {
	if (value === undefined || value === "") return fallback;
	const v = value.trim().toLowerCase();
	if (["0", "false", "off", "no", "disabled"].includes(v)) return false;
	if (["1", "true", "on", "yes", "enabled"].includes(v)) return true;
	return fallback;
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", (event, ctx) => {
		try {
			if (parseEnvBoolean(process.env[DISABLE_ENV], false)) return;

			const toolName = String(event.toolName ?? "");
			if (toolName !== "bash" && toolName !== "powershell") return;

			// Fail-open: if context-mode's ctx_execute isn't active in this
			// session, there is nowhere to redirect the model — don't block.
			const active = pi.getActiveTools();
			if (!active.includes("ctx_execute")) return;

			const input = event.input as { command?: string } | undefined;
			const command = String(input?.command ?? "");
			if (!command) return;

			if (ALLOW_RE.test(command)) return;
			if (FAST_ALLOW_RE.test(command)) return;
			if (!RECURSIVE_SCAN_RE.test(command) && PIPE_CAPPED_RE.test(command)) return;

			if (chainedCommandCount(command) >= 3) {
				return {
					block: true,
					reason:
						"[context-mode-enforcer] 3+ chained commands — use ctx_batch_execute instead of one long bash chain.",
				};
			}

			for (const { re, reason } of BLOCK_PATTERNS) {
				if (re.test(command)) {
					return {
						block: true,
						reason: `[context-mode-enforcer] ${reason}: ${command.slice(0, 200)}`,
					};
				}
			}
		} catch {
			// Never let a guard bug block a legitimate tool call.
		}
	});

	// Safety net: if a non-context tool still returns an oversized result
	// (e.g. an unrecognized command pattern, or a model that ignored the
	// block above via a differently-shaped call), truncate before it enters
	// the next model request. This is a backstop, not the primary control.
	const MAX_RESULT_CHARS = 20_000;
	pi.on("tool_result", (event) => {
		try {
			const toolName = String(event.toolName ?? "");
			if (toolName.startsWith("ctx_")) return; // context-mode manages its own truncation
			const content = event.content;
			if (!Array.isArray(content)) return;

			let changed = false;
			const nextContent = content.map((block) => {
				if (block && typeof block === "object" && "type" in block && block.type === "text") {
					const text = (block as { text?: string }).text ?? "";
					if (text.length > MAX_RESULT_CHARS) {
						changed = true;
						return {
							...block,
							text:
								text.slice(0, MAX_RESULT_CHARS) +
								`\n\n[context-mode-enforcer: truncated ${text.length - MAX_RESULT_CHARS} chars — ` +
								`prefer ctx_execute/ctx_execute_file to avoid this next time]`,
						};
					}
				}
				return block;
			});

			if (changed) return { content: nextContent };
		} catch {
			// Never let the safety net break a legitimate tool result.
		}
	});
}
