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
//
// Optimization stance: the block reason is the ONLY thing that enters context
// when a call is rejected — keep it one short line, name the target tool, and
// never echo the command back (the model just wrote it; echoing is pure burn).
const BLOCK_PATTERNS: Array<{ re: RegExp; reason: string }> = [
	{
		re: /\b(?:python3?|node|ruby|perl|php)\s+(?:-\s*)?<<|<<\s*['\"]?EOF\b|\b(?:python3?|node|ruby|perl|php)\s+-[ec]\b/,
		reason: "inline interpreter via bash — use ctx_execute(language python/typescript/ruby/perl)",
	},
	{
		re: /\b(cat|head|tail|less|more)\b/,
		reason: "file dump — use ctx_execute_file to analyze instead of reading raw",
	},
	{
		re: /\bfind\b.*-type|ls\s+-R|\bgrep\s+-[a-zA-Z]*r\b/,
		reason: "recursive scan — use ctx_execute (shell) or ctx_batch_execute",
	},
	{
		re: /\b(curl|wget)\b/,
		reason: "raw HTTP — use ctx_execute fetch(), or ctx_fetch_and_index for docs",
	},
	{
		re: /\b(npm|pnpm|yarn)\s+(test|run\s+test|ls|outdated|audit)\b|\bpytest\b|\bgo\s+test\b|\bvitest\b/,
		reason: "test/build runner — use ctx_execute to capture + summarize",
	},
	{
		re: /\bgit\s+(log\s+-p|diff)\b/,
		reason: "large git output — use ctx_execute to capture + summarize",
	},
	{
		re: /\bdocker\s+(ps|logs|inspect)\b|\bkubectl\s+get\b/,
		reason: "infra inspection — use ctx_execute to capture + summarize",
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
				return { block: true, reason: "[ctx] 3+ chained commands — use ctx_batch_execute" };
			}

			for (const { re, reason } of BLOCK_PATTERNS) {
				if (re.test(command)) {
					return { block: true, reason: `[ctx] ${reason}` };
				}
			}
		} catch {
			// Never let a guard bug block a legitimate tool call.
		}
	});

	// Recursion + unbounded-runtime guard for the ctx tools themselves.
	// Moved here from pi-yaml-hooks: tool.before.ctx_* hooks could not be
	// validated against custom tool names (load advisories on every session).
	// Same policy for every provider:
	//   1. Recursive filesystem scan (grep -r/-R, find, tree, du) without a
	//      tool `timeout` is rejected; bytes-capped output does NOT bound
	//      run time.
	//   2. ssh/wsl inside a ctx tool must (a) never start a never-exiting
	//      remote program and (b) carry -o ConnectTimeout when the call has
	//      no timeout.
	const ctxRecursiveScanRe = /\b(grep -[rR]|find |tree |du )/;
	const sshLikeRe = /\b(ssh|wsl|wsl\.exe)\b/;
	const neverExitingRemoteRe = /wscript|cscript|mshta|sleep +infinity|tail +-f|bash +-i|ssh +-t\b/;

	function guardCtxTool(toolName: string, code: string, timeout: unknown): string | undefined {
		if (!code) return undefined;
		const unbounded = timeout === undefined || timeout === null;

		if (unbounded && ctxRecursiveScanRe.test(code)) {
			const hasShellTimeout = /(^|[\s;&])timeout +[0-9]/.test(code);
			if (!hasShellTimeout) {
				return "[ctx-guard] recursive filesystem scan (grep -r/-R|find|tree|du) inside a ctx tool without a timeout — pass 'timeout: 120000', or bound the scan (rg --max-time 10 / --max-depth 3, scoped path). Bytes-capped (head/tail) does NOT bound run time.";
			}
		}

		if (unbounded) {
			for (const line of code.split("\n")) {
				if (sshLikeRe.test(line) && neverExitingRemoteRe.test(line)) {
					return "[ssh-guard] never-exiting remote program (wscript/cscript/mshta/sleep infinity/tail -f/interactive shell/forced tty) over ssh/wsl — bound it remotely ('timeout <n> <cmd>', 'cmd /c <n> <cmd>') or make it exit. This pattern already orphaned a Paseo agent (unrecoverable cancel bug).";
				}
			}
			if (/\bssh\s/.test(code) && !/ConnectTimeout=[0-9]+/.test(code)) {
				return "[ssh-guard] ssh without ConnectTimeout and no tool timeout: add '-o ConnectTimeout=10' to each ssh (remote command as arg, no tty, no interactive shell). ssh over SSH hangs forever in RPC tools.";
			}
		}
		return undefined;
	}

	pi.on("tool_call", (event, ctx) => {
		try {
			const toolName = String(event.toolName ?? "");
			if (toolName === "ctx_execute" || toolName === "ctx_batch_execute") {
				if (parseEnvBoolean(process.env[DISABLE_ENV], false)) return;
				const input = event.input as { code?: string; commands?: Array<{ command?: string }>; timeout?: number } | undefined;
				if (input) {
					const code =
						toolName === "ctx_execute"
							? String(input.code ?? "")
							: (input.commands ?? []).map((c) => c?.command ?? "").join("\n");
					const verdict = guardCtxTool(toolName, code, input.timeout);
					if (verdict) return { block: true, reason: verdict };
				}
				return;
			}
		} catch {
			// Never let a guard bug block a legitimate tool call.
		}
	});

	// Safety net: if a non-context tool still returns an oversized result
	// (e.g. an unrecognized command pattern, MCP output, or a model that
	// ignored the redirect above), COMPACT before it enters the next model
	// request. Backstop, not primary control. Aligned with RTK output
	// compaction (truncate.maxChars: 12000) so every path hits the same
	// ceiling, but this cut is AI-readable rather than a dumb head-chop:
	//   1. strip ANSI escape sequences (mcporter/CLI bridges leak them)
	//   2. squeeze 3+ blank lines to one
	//   3. keep head (file paths / structure) AND tail (errors live there)
	//      with an explicit trimmed-chars marker in between.
	const MAX_RESULT_CHARS = 12_000;
	const HEAD_KEEP = 9_000;
	const TAIL_KEEP = 2_500;
	const ANSI_RE = /\x1b\[[0-9;]*[A-Za-z]|\x1b\][^\x07]*(?:\x07|\x1b\\)/g;

	function compactResultText(text: string): string | null {
		// ANSI strip + blank-line squeeze first: these reduce length without
		// losing any information.
		let out = text.replace(ANSI_RE, "").replace(/\n{3,}/g, "\n\n");
		if (out.length <= MAX_RESULT_CHARS) {
			return out === text ? null : out; // null = unchanged, skip rebuild
		}
		const trimmed = out.length - HEAD_KEEP - TAIL_KEEP;
		out =
			out.slice(0, HEAD_KEEP) +
			`\n\n[ctx: ${trimmed} chars trimmed — head+tail kept; rerun via ctx_execute/ctx_execute_file for full Indexed output]\n\n` +
			out.slice(-TAIL_KEEP);
		return out;
	}

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
					if (!text) return block;
					const compacted = compactResultText(text);
					if (compacted !== null) {
						changed = true;
						return { ...block, text: compacted };
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
