/**
 * llmtrim-guard — keep Pi fail-open and self-healing for the local proxy.
 *
 * session_start: start/poll llmtrim; enable proxy env if healthy, else clear.
 * Fail path: proxy-ish provider/message errors → one cooldown recover attempt.
 * /llmtrim on|off|check|heal — mutate this process env for the running Pi.
 */
import { execFileSync, spawnSync } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const PORT = "43117";
const PROXY = `http://127.0.0.1:${PORT}`;
const NO_PROXY =
	"localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,fd00::/8,*.local,*.cursor.sh,*.cursor.com,cursor.sh,cursor.com,api2.cursor.sh";
const COOLDOWN_MS = 30_000;
const PROXY_FAIL_RE =
	/econnrefused|econnreset|etimedout|socket hang up|tunnel|proxy|fetch failed|43117|unable to connect|network\s*error/i;

const CLEAR_KEYS = [
	"HTTPS_PROXY",
	"HTTP_PROXY",
	"ALL_PROXY",
	"https_proxy",
	"http_proxy",
	"all_proxy",
	"NODE_EXTRA_CA_CERTS",
	"SSL_CERT_FILE",
	"CURL_CA_BUNDLE",
	"NODE_USE_ENV_PROXY",
	"NO_PROXY",
	"no_proxy",
] as const;

function caPem(): string {
	return join(homedir(), ".llmtrim", "ca.pem");
}

function caBundle(): string {
	return join(homedir(), ".llmtrim", "ca-bundle.pem");
}

function hasLlmtrim(): boolean {
	const r = spawnSync("which", ["llmtrim"], { encoding: "utf8" });
	return r.status === 0 && Boolean(r.stdout?.trim());
}

function alive(): boolean {
	try {
		execFileSync("llmtrim", ["_alive"], { stdio: "ignore", timeout: 2000 });
		return true;
	} catch {
		return false;
	}
}

function startDaemon(): void {
	try {
		execFileSync("llmtrim", ["start"], { stdio: "ignore", timeout: 5000 });
	} catch {
		/* fail open below */
	}
}

function pollAlive(attempts = 4): boolean {
	for (let i = 0; i < attempts; i++) {
		if (alive()) return true;
		if (i < attempts - 1) {
			spawnSync("sleep", ["0.25"]);
		}
	}
	return alive();
}

function clearEnv(): void {
	for (const key of CLEAR_KEYS) {
		delete process.env[key];
	}
}

function enableEnv(): void {
	process.env.HTTPS_PROXY = PROXY;
	process.env.HTTP_PROXY = PROXY;
	process.env.NO_PROXY = NO_PROXY;
	process.env.no_proxy = NO_PROXY;
	process.env.NODE_USE_ENV_PROXY = "1";
	process.env.NODE_EXTRA_CA_CERTS = caPem();
	process.env.SSL_CERT_FILE = caBundle();
	process.env.CURL_CA_BUNDLE = caBundle();
}

function proxyPointsAtLlmtrim(): boolean {
	const v = process.env.HTTPS_PROXY || process.env.https_proxy || "";
	return v.includes(`:${PORT}`) || v.includes("127.0.0.1:43117");
}

/** Heal or fail-open. Returns "proxied" | "direct". */
function healOrFailOpen(): "proxied" | "direct" {
	if (!hasLlmtrim()) {
		clearEnv();
		return "direct";
	}
	if (!alive()) {
		startDaemon();
		pollAlive();
	}
	if (alive()) {
		enableEnv();
		return "proxied";
	}
	clearEnv();
	return "direct";
}

function extractErrorText(message: unknown): string {
	if (!message || typeof message !== "object") return "";
	const m = message as {
		stopReason?: string;
		errorMessage?: string;
		content?: unknown;
		details?: { error?: string };
	};
	const parts: string[] = [];
	if (m.stopReason) parts.push(String(m.stopReason));
	if (m.errorMessage) parts.push(String(m.errorMessage));
	if (m.details?.error) parts.push(String(m.details.error));
	if (Array.isArray(m.content)) {
		for (const block of m.content) {
			if (block && typeof block === "object" && "text" in block) {
				parts.push(String((block as { text?: string }).text ?? ""));
			}
		}
	}
	return parts.join("\n");
}

function looksLikeProxyFailure(text: string): boolean {
	return Boolean(text) && PROXY_FAIL_RE.test(text);
}

function statusLine(): string {
	const mode = proxyPointsAtLlmtrim() ? "proxied" : "direct";
	const health = hasLlmtrim() ? (alive() ? "alive" : "down") : "missing";
	const proxy = process.env.HTTPS_PROXY || "(unset)";
	return `llmtrim ${health} · mode ${mode} · HTTPS_PROXY=${proxy}`;
}

export default function llmtrimGuard(pi: ExtensionAPI) {
	let lastRecoverAt = 0;

	async function recover(ctx: ExtensionContext, reason: string): Promise<void> {
		const now = Date.now();
		if (now - lastRecoverAt < COOLDOWN_MS) return;
		lastRecoverAt = now;

		const mode = healOrFailOpen();
		if (!ctx.hasUI) return;
		if (mode === "proxied") {
			ctx.ui.notify(
				`llmtrim healed (${reason}). Retry the turn to use the proxy.`,
				"info",
			);
		} else {
			ctx.ui.notify(
				`llmtrim down (${reason}); fail-open direct. Retry the turn, or /llmtrim on later.`,
				"warning",
			);
		}
	}

	pi.on("session_start", async (_event, ctx) => {
		if (!hasLlmtrim()) return;
		const mode = healOrFailOpen();
		if (!ctx.hasUI) return;
		if (mode === "direct") {
			ctx.ui.notify(
				"llmtrim unavailable — Pi fail-open (direct, no proxy).",
				"warning",
			);
		}
	});

	pi.on("after_provider_response", async (event, ctx) => {
		if (!proxyPointsAtLlmtrim()) return;
		// Typical bad-gateway / proxy dead statuses when something answers on the port
		if (event.status === 502 || event.status === 503 || event.status === 504) {
			await recover(ctx, `HTTP ${event.status}`);
		}
	});

	pi.on("message_end", async (event, ctx) => {
		if (!proxyPointsAtLlmtrim()) return;
		const text = extractErrorText(event.message);
		if (!looksLikeProxyFailure(text)) return;
		await recover(ctx, "provider error");
	});

	pi.registerCommand("llmtrim", {
		description: "llmtrim proxy: on | off | check | heal",
		handler: async (args, ctx) => {
			if (!ctx.hasUI) return;
			const cmd = (args || "check").trim().split(/\s+/)[0]?.toLowerCase() || "check";

			if (cmd === "off") {
				try {
					execFileSync("llmtrim", ["stop"], { stdio: "ignore", timeout: 5000 });
				} catch {
					/* ignore */
				}
				clearEnv();
				ctx.ui.notify("llmtrim disabled for this Pi process; direct connections enabled", "info");
				return;
			}

			if (cmd === "on" || cmd === "heal") {
				const mode = healOrFailOpen();
				if (mode === "proxied") {
					ctx.ui.notify("llmtrim enabled for this Pi process", "info");
				} else {
					ctx.ui.notify(
						"llmtrim failed to start; direct connections remain enabled",
						"error",
					);
				}
				return;
			}

			if (cmd === "check" || cmd === "status") {
				ctx.ui.notify(statusLine(), "info");
				return;
			}

			ctx.ui.notify("Usage: /llmtrim on|off|check|heal", "warning");
		},
	});
}
