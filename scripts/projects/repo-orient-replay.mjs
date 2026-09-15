#!/usr/bin/env node
/**
 * R0-09: replay sampled Pi task units through repo-orient.py and measure.
 * Output: ~/.cache/repo-orientation/r0-09-replay.{json,md}
 */
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { execFileSync } from "node:child_process";

const home = os.homedir();
const sessionsRoot = path.join(home, ".pi/agent/sessions");
const outDir = path.join(home, ".cache/repo-orientation");
const orientPy = path.join(home, "dotfiles/scripts/projects/repo-orient.py");
fs.mkdirSync(outDir, { recursive: true });

const READ = new Set(["read", "ctx_execute_file", "pi__ctx_execute_file"]);
const MUTATE = new Set(["write", "edit", "apply_patch", "StrReplace", "search_replace"]);
const pct = (arr, p) => {
  if (!arr.length) return 0;
  const s = [...arr].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))];
};

function walk(dir, out = []) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(p, out);
    else if (ent.name.endsWith(".jsonl")) out.push(p);
  }
  return out;
}

// Extract units with ground-truth touched files (pre-edit reads/edits).
function unitsFromSession(file) {
  let entries;
  try {
    entries = fs.readFileSync(file, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
  } catch { return []; }
  const session = entries.find((e) => e.type === "session");
  const cwd = session?.cwd || "";
  if (!cwd || !fs.existsSync(cwd)) return [];
  const events = [];
  for (const e of entries) {
    if (e.type !== "message") continue;
    const m = e.message;
    if (!m) continue;
    if (m.role === "assistant" && Array.isArray(m.content)) {
      for (const b of m.content) {
        if (b.type === "toolCall") events.push({ type: "call", name: b.name, args: b.arguments || {} });
      }
    }
    if (m.role === "toolResult") {
      const chars = (m.content || []).reduce((s, p) => s + (p.text?.length || 0), 0);
      events.push({ type: "result", chars });
    }
    if (m.role === "user") {
      const text = typeof m.content === "string" ? m.content
        : (m.content || []).filter((x) => x.type === "text").map((x) => x.text).join("\n");
      events.push({ type: "user", text });
    }
  }
  const units = [];
  let i = 0;
  while (i < events.length) {
    while (i < events.length && events[i].type !== "user") i++;
    if (i >= events.length) break;
    const user = events[i].text?.trim();
    i++;
    if (!user || user.length < 12) continue;
    const calls = [];
    let sawMutate = false;
    while (i < events.length && events[i].type !== "user") {
      const ev = events[i++];
      if (ev.type === "call") {
        const n = ev.name.replace(/^pi__/, "");
        const kind = MUTATE.has(ev.name) || MUTATE.has(n) ? "mutate" : "other";
        const gt = [];
        for (const k of ["path", "file_path", "filepath"]) {
          if (typeof ev.args[k] === "string") gt.push(ev.args[k]);
        }
        calls.push({ kind, resultChars: 0, attached: false, gtPaths: kind === "mutate" ? gt : gt.filter(() => READ.has(n) || n === "read") , isMutate: kind === "mutate", gt });
        if (kind === "mutate") sawMutate = true;
      } else if (ev.type === "result") {
        for (let j = calls.length - 1; j >= 0; j--) {
          if (!calls[j].attached) { calls[j].resultChars = ev.chars; calls[j].attached = true; break; }
        }
      }
    }
    if (!calls.length) continue;
    const mutateIdx = calls.findIndex((c) => c.isMutate);
    const mapping = mutateIdx >= 0 ? calls.slice(0, mutateIdx) : calls;
    if (!mapping.length) continue;
    const resultBytes = mapping.reduce((s, c) => s + (c.resultChars || 0), 0);
    const baselineTokens = Math.ceil(resultBytes / 4);
    // ground truth: files the session actually read pre-edit + first edit target
    const gtPaths = new Set();
    for (const c of calls) {
      for (const p of c.gt || []) gtPaths.add(p);
    }
    if (gtPaths.size === 0) continue; // no verifiable ground truth
    units.push({ task: user.slice(0, 160), cwd, baselineTokens, gtPaths: [...gtPaths], hadMutate: sawMutate, sessionFile: file });
  }
  return units;
}

// Collect units, stratified sample of 30 with ground truth
const sessionFiles = walk(sessionsRoot);
const allUnits = [];
for (const f of sessionFiles) {
  try { allUnits.push(...unitsFromSession(f)); } catch {}
}
// dedupe similar tasks, prefer units with meaningful baseline
const seen = new Set();
const pool = allUnits.filter((u) => {
  const key = u.cwd + "|" + u.task.slice(0, 40).toLowerCase();
  if (seen.has(key)) return false;
  seen.add(key);
  return u.baselineTokens >= 200;
});
pool.sort((a, b) => b.baselineTokens - a.baselineTokens);
const buckets = new Map();
for (const u of pool) {
  const top = u.cwd.split("/").filter(Boolean).slice(-2).join("/");
  if (!buckets.has(top)) buckets.set(top, []);
  buckets.get(top).push(u);
}
const sample = [];
const keys = [...buckets.keys()].sort();
for (let round = 0; sample.length < 30 && round < 50; round++) {
  for (const k of keys) {
    const arr = buckets.get(k);
    if (arr.length > round) sample.push(arr[round]);
    if (sample.length >= 30) break;
  }
}

const results = [];
let orientErrors = 0;
for (const u of sample) {
  const t0 = Date.now();
  let orientOut = null;
  try {
    orientOut = JSON.parse(execFileSync("python3", [orientPy, "orient", u.task, "--path", u.cwd], {
      encoding: "utf8", timeout: 60000,
    }));
  } catch { orientErrors++; }
  const latencyMs = Date.now() - t0;
  if (!orientOut) {
    results.push({ task: u.task.slice(0, 60), cwd: u.cwd, status: "orient_error", latencyMs });
    continue;
  }
  const routes = (orientOut.read_next || []).map((r) => r.path);
  const orientTokens = Math.ceil(JSON.stringify(orientOut).length / 4);
  // correctness: normalize ground-truth abs paths to repo-relative; hit if any route matches
  let hit = false;
  let firstRouteCorrect = false;
  const gtRel = u.gtPaths.map((p) => (p.startsWith(u.cwd) ? p.slice(u.cwd.length + 1) : p));
  const gtSet = new Set(gtRel);
  if (routes.length && gtSet.size) {
    hit = routes.some((r) => gtSet.has(r));
    firstRouteCorrect = gtSet.has(routes[0]);
  }
  // broader judge: path or basename referenced anywhere in the session transcript
  let referenced = false;
  try {
    const sessionText = fs.readFileSync(u.sessionFile, "utf8");
    referenced = routes.some((r) => {
      const base = r.split("/").pop();
      return sessionText.includes(r) || (base.length > 6 && sessionText.includes(base));
    });
  } catch {}
  const firstScore = (orientOut.read_next || [])[0]?.score ?? 0;
  results.push({
    task: u.task.slice(0, 60),
    cwd: u.cwd.split("/").filter(Boolean).slice(-2).join("/"),
    baselineTokens: u.baselineTokens,
    orientTokens,
    routes,
    hit,
    firstRouteCorrect,
    referenced,
    ambiguous: firstScore < 4,
    latencyMs,
    status: "ok",
  });
}

const ok = results.filter((r) => r.status === "ok");
const tokensOrient = ok.map((r) => r.orientTokens);
const tokensBase = ok.map((r) => r.baselineTokens);
const judgeable = ok.filter((r) => r.routes.length > 0);
const correct = judgeable.filter((r) => r.hit);
const firstCorrect = judgeable.filter((r) => r.firstRouteCorrect);
const medianBase = pct(tokensBase, 50);
const medianOrient = pct(tokensOrient, 50);
const report = {
  plan_id: "repo-orientation-mvp",
  task_id: "R0-09",
  generated_at: new Date().toISOString(),
  units_with_ground_truth: allUnits.length,
  sampled: results.length,
  orient_errors: orientErrors,
  median_baseline_tokens: medianBase,
  median_orient_tokens: medianOrient,
  reduction_pct: medianBase ? Math.round((1 - medianOrient / medianBase) * 100) : null,
  route_hit_rate: judgeable.length ? correct.length / judgeable.length : null,
  first_route_correct_rate: judgeable.length ? firstCorrect.length / judgeable.length : null,
  referenced_rate: judgeable.length ? judgeable.filter((r) => r.referenced).length / judgeable.length : null,
  unambiguous_n: judgeable.filter((r) => !r.ambiguous).length,
  unambiguous_referenced_rate: (() => {
    const un = judgeable.filter((r) => !r.ambiguous);
    return un.length ? un.filter((r) => r.referenced).length / un.length : null;
  })(),
  p95_latency_ms: pct(results.map((r) => r.latencyMs), 95),
  gate: {
    token_reduction_target: ">=60%",
    first_route_target: ">=90% on judgeable units",
  },
  results,
};
fs.writeFileSync(path.join(outDir, "r0-09-replay.json"), JSON.stringify(report, null, 2) + "\n");
const md = [
  "# R0-09 replay",
  `Generated: ${report.generated_at}`,
  `Sampled: ${report.sampled} (errors: ${orientErrors})`,
  `Median baseline tokens: ${medianBase}`,
  `Median orient tokens: ${medianOrient}`,
  `Reduction: ${report.reduction_pct}%`,
  `Route hit rate (any of ≤3): ${report.route_hit_rate}`,
  `First-route correct: ${report.first_route_correct_rate}`,
  `P95 orient latency: ${report.p95_latency_ms} ms`,
].join("\n");
fs.writeFileSync(path.join(outDir, "r0-09-replay.md"), md + "\n");
console.log("baseline", medianBase, "orient", medianOrient, "reduction%", report.reduction_pct, "hit", report.route_hit_rate, "referenced", report.referenced_rate, "unambig_referenced", report.unambiguous_referenced_rate, "p95ms", report.p95_latency_ms);
