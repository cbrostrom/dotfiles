#!/usr/bin/env node
/**
 * peer-resolve — compact peer/agent resolution for the /call skill.
 *
 * Modes:
 *   agents [pattern]       list Paseo agents (paseo ls --json), filtered
 *   peers  [pattern]       list pi-peer sessions from ~/.pi/agent/peers, filtered
 *   prune  [--days N]      remove offline pi-peer records older than N days
 *                          (default 7) whose inboxes are empty — never deletes mail
 *
 * Output is deliberately small (<= 20 rows): the caller routes by project
 * directory, not by peer contents, so a full roster is never needed.
 */

import { readdirSync, readFileSync, rmSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

const PEERS_DIR = process.env.PI_PEER_DIR ?? join(homedir(), ".pi", "agent", "peers");
const STALE_AFTER_MS = 45_000; // must match pi-peer's registry.ts
const MAX_ROWS = 20;

function usage() {
	console.error("usage: peer-resolve.mjs agents|peers [pattern] | prune [--days N]");
	process.exit(2);
}

function matches(pattern, ...fields) {
	if (!pattern) return true;
	const p = pattern.toLowerCase();
	return fields.some((f) => typeof f === "string" && f.toLowerCase().includes(p));
}

function printRow(cols) {
	console.log(cols.join(" | "));
}

// --- peers mode -----------------------------------------------------------

/** Presence mirrors pi-peer's registry.ts: live beats, stalled pid, offline else. */
function presence(record, now) {
	const stale = now - record.beatAt > STALE_AFTER_MS;
	const pidAlive =
		typeof record.pid === "number" &&
		(() => {
			try {
				process.kill(record.pid, 0);
				return true;
			} catch {
				return false;
			}
		})();
	if (pidAlive && !stale) return "live";
	if (pidAlive) return "stalled";
	return "offline";
}

function mailCount(id) {
	const inbox = join(PEERS_DIR, `${id}.inbox`);
	try {
		return readdirSync(inbox).length;
	} catch {
		return 0;
	}
}

function cmdPeers(pattern) {
	const now = Date.now();
	const files = existsSync(PEERS_DIR) ? readdirSync(PEERS_DIR) : [];
	const records = files
		.filter((f) => f.endsWith(".json"))
		.map((f) => {
			try {
				return JSON.parse(readFileSync(join(PEERS_DIR, f), "utf8"));
			} catch {
				return null; // half-written record: treat as absent, like pi-peer does
			}
		})
		.filter(Boolean);

	const live = records.filter((r) => presence(r, now) !== "offline");
	const dead = records.filter((r) => presence(r, now) === "offline");

	// Live and stalled first, offline only when nothing live matches.
	let rows = live.filter((r) => matches(pattern, r.name, r.cwd));
	if (rows.length === 0) rows = dead.filter((r) => matches(pattern, r.name, r.cwd));
	rows.sort((a, b) => (presence(b, now) === "live" ? 1 : 0) - (presence(a, now) === "live" ? 1 : 0));

	if (rows.length === 0) return console.log(`no peers matching ${pattern ?? "(all)"}`);
	printRow(["name", "cwd", "presence", "mail"]);
	for (const r of rows.slice(0, MAX_ROWS)) {
		printRow([r.name, r.cwd.replace(/^\/Users\/[^/]+/, "~"), presence(r, now), String(mailCount(r.id))]);
	}
	if (rows.length > MAX_ROWS) console.log(`… and ${rows.length - MAX_ROWS} more; narrow the pattern`);
}

// --- agents mode ----------------------------------------------------------

function cmdAgents(pattern) {
	let raw;
	try {
		raw = execFileSync("paseo", ["ls", "--json"], { encoding: "utf8", timeout: 15_000 });
	} catch (e) {
		return console.error(`paseo ls failed: ${e.message}`);
	}
	let agents;
	try {
		agents = JSON.parse(raw);
	} catch {
		return console.error("paseo ls --json returned invalid JSON");
	}
	if (!Array.isArray(agents)) agents = agents?.agents ?? [];

	const rows = agents.filter((a) => matches(pattern, a.name, a.cwd, a.shortId, a.id));
	if (rows.length === 0) return console.log(`no agents matching ${pattern ?? "(all)"}`);
	printRow(["shortId", "status", "cwd", "name"]);
	for (const a of rows.slice(0, MAX_ROWS)) {
		printRow([a.shortId ?? a.id, a.status ?? "?", (a.cwd ?? "?").replace(/^\/Users\/[^/]+/, "~"), a.name ?? ""]);
	}
	if (rows.length > MAX_ROWS) console.log(`… and ${rows.length - MAX_ROWS} more; narrow the pattern`);
}

// --- prune mode -----------------------------------------------------------

function cmdPrune(daysArg) {
	const days = daysArg ?? 7;
	const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;
	const now = Date.now();
	let pruned = 0;
	let kept = 0;

	const files = existsSync(PEERS_DIR) ? readdirSync(PEERS_DIR).filter((f) => f.endsWith(".json")) : [];
	for (const f of files) {
		const id = f.replace(/\.json$/, "");
		let record;
		try {
			record = JSON.parse(readFileSync(join(PEERS_DIR, f), "utf8"));
		} catch {
			kept++;
			continue;
		}
		if (presence(record, now) !== "offline" || record.beatAt > cutoff) {
			kept++;
			continue;
		}
		const inbox = join(PEERS_DIR, `${id}.inbox`);
		let count = 0;
		try {
			count = readdirSync(inbox).length;
		} catch {
			/* no inbox */
		}
		if (count > 0) {
			kept++; // mail waiting for a resumed session is never deleted
			continue;
		}
		rmSync(join(PEERS_DIR, f), { force: true });
		rmSync(inbox, { recursive: true, force: true });
		pruned++;
	}
	console.log(`pruned ${pruned} empty offline records (>${days}d), kept ${kept}`);
}

// ESM top-level dispatch
const [, , mode, ...rest] = process.argv;
if (mode === "prune") {
	const di = rest.indexOf("--days");
	cmdPrune(di >= 0 ? Number(rest[di + 1]) : undefined);
} else if (mode === "peers") {
	cmdPeers(rest[0]);
} else if (mode === "agents") {
	cmdAgents(rest[0]);
} else {
	usage();
}
