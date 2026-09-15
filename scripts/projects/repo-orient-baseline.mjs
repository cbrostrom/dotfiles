#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const home = os.homedir();
const sessionsRoot = path.join(home, ".pi/agent/sessions");
const outDir = path.join(home, ".cache/repo-orientation");
fs.mkdirSync(outDir, { recursive: true });

const DISCOVERY = new Set([
  "rg", "grep", "fd", "glob", "ls", "ctx_search", "ctx_batch_execute", "ctx_execute",
  "ctx_index", "ctx_fetch_and_index", "search_graph", "query_graph", "trace_path",
  "get_architecture", "search_code", "list_projects", "pi__rg", "pi__fd", "pi__ctx_search",
  "pi__ctx_batch_execute", "cursor_activate_skill", "pi__cursor_activate_skill",
]);
const READ = new Set(["read", "ctx_execute_file", "pi__ctx_execute_file"]);
const MUTATE = new Set(["write", "edit", "apply_patch", "StrReplace", "search_replace"]);

const pct = (arr, p) => {
  if (!arr.length) return 0;
  const s = [...arr].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))];
};

function projectClass(cwd) {
  if (!cwd) return "unknown";
  if (cwd.includes("/dotfiles")) return "dotfiles";
  if (cwd.includes("/Vaults/")) return "vault";
  if (/shopify/i.test(cwd)) return "shopify";
  if (/\/Projects\/(private|Private)\//.test(cwd)) return "private-app";
  if (cwd.includes("/Projects/work/")) return "work-client";
  if (cwd.includes("/Projects/")) return "projects-other";
  return "other";
}

function taskClass(text) {
  const t = (text || "").toLowerCase();
  if (/\b(test|spec|failing|coverage)\b/.test(t)) return "test-failure";
  if (/\b(hook|config|dotfiles|symlink)\b/.test(t)) return "config-hook";
  if (/\b(doc|readme|changelog)\b/.test(t)) return "documentation";
  if (/\b(where|how does|find|locate|orient|map)\b/.test(t)) return "unfamiliar-feature";
  if (/\b(mcp|integrat|cross.?repo|api)\b/.test(t)) return "cross-integration";
  if (/\b(import|package|module|dependency)\b/.test(t)) return "cross-package";
  if (/\b(bug|fix|broken|error|fail)\b/.test(t)) return "bug-trace";
  return "general-implement";
}

function bashKind(cmd) {
  const c = String(cmd || "").toLowerCase();
  if (/\b(find|fd |rg |grep |tree |git ls-files|ls -)/.test(c)) return "discovery";
  if (/\b(cat |head |tail )\b/.test(c) && /\.(md|ts|tsx|js|go|py|sh|json|yaml|yml)\b/.test(c)) return "read";
  return "shell-other";
}

function toolKind(name, args = {}) {
  const n = (name || "").replace(/^pi__/, "");
  if (MUTATE.has(name) || MUTATE.has(n)) return "mutate";
  if (READ.has(name) || READ.has(n)) return "read";
  if (DISCOVERY.has(name) || DISCOVERY.has(n)) return "discovery";
  if (name === "bash") return bashKind(args.command);
  if (/search|graph|architecture|index|glob|list/i.test(name || "")) return "discovery";
  if (/read|execute_file/i.test(name || "")) return "read";
  if (/write|edit|patch|replace/i.test(name || "")) return "mutate";
  return "other";
}

function walk(dir, out = []) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(p, out);
    else if (ent.name.endsWith(".jsonl")) out.push(p);
  }
  return out;
}

function parse(file) {
  const entries = fs.readFileSync(file, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
  const session = entries.find((e) => e.type === "session");
  const cwd = session?.cwd || "";
  const chronological = [];
  for (const e of entries) {
    if (e.type !== "message") continue;
    const m = e.message;
    if (!m) continue;
    if (m.role === "assistant" && Array.isArray(m.content)) {
      for (const b of m.content) {
        if (b.type === "toolCall") chronological.push({ type: "call", name: b.name, args: b.arguments || {} });
      }
    }
    if (m.role === "toolResult") {
      const chars = (m.content || []).reduce((s, p) => s + (p.text?.length || 0), 0);
      chronological.push({ type: "result", chars });
    }
    if (m.role === "user") {
      const text = typeof m.content === "string" ? m.content : (m.content || []).filter((x) => x.type === "text").map((x) => x.text).join("\n");
      chronological.push({ type: "user", text });
    }
  }
  return { cwd, projectClass: projectClass(cwd), chronological };
}

function units(chronological) {
  const out = [];
  let i = 0;
  while (i < chronological.length) {
    while (i < chronological.length && chronological[i].type !== "user") i++;
    if (i >= chronological.length) break;
    const user = chronological[i].text?.trim();
    i++;
    if (!user || user.length < 12) continue;
    const calls = [];
    let sawMutate = false;
    while (i < chronological.length && chronological[i].type !== "user") {
      const ev = chronological[i++];
      if (ev.type === "call") {
        const kind = toolKind(ev.name, ev.args);
        calls.push({ kind, resultChars: 0, attached: false });
        if (kind === "mutate") sawMutate = true;
      } else if (ev.type === "result") {
        for (let j = calls.length - 1; j >= 0; j--) {
          if (!calls[j].attached) { calls[j].resultChars = ev.chars; calls[j].attached = true; break; }
        }
      }
    }
    const mutateIdx = calls.findIndex((c) => c.kind === "mutate");
    const mapping = mutateIdx >= 0 ? calls.slice(0, mutateIdx) : calls;
    if (!mapping.length) continue;
    const resultBytes = mapping.reduce((s, c) => s + (c.resultChars || 0), 0);
    out.push({
      userPreview: user.slice(0, 120),
      taskClass: taskClass(user),
      discoveryCalls: mapping.filter((c) => c.kind === "discovery").length,
      readCalls: mapping.filter((c) => c.kind === "read").length,
      mappingToolCalls: mapping.length,
      estMappingTokens: Math.ceil(resultBytes / 4),
      hadMutate: sawMutate,
    });
  }
  return out;
}

const sessionFiles = walk(sessionsRoot);
const allUnits = [];
for (const f of sessionFiles) {
  try {
    const p = parse(f);
    units(p.chronological).forEach((u) => allUnits.push({ ...u, projectClass: p.projectClass }));
  } catch {}
}

const buckets = new Map();
for (const u of allUnits) {
  const key = `${u.projectClass}|${u.taskClass}`;
  if (!buckets.has(key)) buckets.set(key, []);
  buckets.get(key).push(u);
}
const sample = [];
const keys = [...buckets.keys()].sort();
for (let round = 0; sample.length < 40 && round < 50; round++) {
  for (const k of keys) {
    const arr = buckets.get(k);
    if (arr.length > round) sample.push(arr[round]);
    if (sample.length >= 40) break;
  }
}

const tokens = sample.map((s) => s.estMappingTokens);
const toolCalls = sample.map((s) => s.mappingToolCalls);
const report = {
  plan_id: "repo-orientation-mvp",
  task_id: "R0-01",
  generated_at: new Date().toISOString(),
  method: "Pi JSONL replay; mapping window = user turn until first mutate; tokens = ceil(toolResultBytes/4)",
  sessions_scanned: sessionFiles.length,
  candidate_units: allUnits.length,
  sample_size: sample.length,
  aggregates: {
    median_mapping_tokens: pct(tokens, 50),
    p75_mapping_tokens: pct(tokens, 75),
    p90_mapping_tokens: pct(tokens, 90),
    median_mapping_tool_calls: pct(toolCalls, 50),
    p75_mapping_tool_calls: pct(toolCalls, 75),
    mean_discovery_calls: sample.length ? sample.reduce((s, x) => s + x.discoveryCalls, 0) / sample.length : 0,
    mean_read_calls: sample.length ? sample.reduce((s, x) => s + x.readCalls, 0) / sample.length : 0,
  },
  samples: sample,
};

const jsonPath = path.join(outDir, "r0-01-baseline.json");
fs.writeFileSync(jsonPath, JSON.stringify(report, null, 2) + "\n");
const md = [
  "# R0-01 mapping-token baseline",
  `Generated: ${report.generated_at}`,
  `Sessions scanned: ${report.sessions_scanned}`,
  `Sample units: ${report.sample_size}`,
  "",
  "## Aggregates",
  `- Median mapping tokens: **${report.aggregates.median_mapping_tokens}**`,
  `- P75 mapping tokens: **${report.aggregates.p75_mapping_tokens}**`,
  `- P90 mapping tokens: **${report.aggregates.p90_mapping_tokens}**`,
  `- Median mapping tool calls: **${report.aggregates.median_mapping_tool_calls}**`,
  `- P75 mapping tool calls: **${report.aggregates.p75_mapping_tool_calls}**`,
  "",
  "MVP gate (R0-09): ≥60% median reduction vs this baseline.",
].join("\n");
fs.writeFileSync(path.join(outDir, "r0-01-baseline.md"), md + "\n");
console.log(jsonPath);
console.log("median", report.aggregates.median_mapping_tokens, "p75", report.aggregates.p75_mapping_tokens);
