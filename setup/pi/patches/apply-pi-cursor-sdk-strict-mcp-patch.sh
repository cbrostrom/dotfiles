#!/usr/bin/env bash
# Force Cursor SDK local agents to MCP-only tools so every Cursor action
# (search, read, edit, shell) is bridged through pi-cursor-sdk's local MCP
# bridge instead of Cursor's native tool loop.
#
# Why: Cursor's native tools (webSearch, webFetch, shell, read, edit via
# @cursor/sdk) never fire Pi's `tool_call` extension event — they run inside
# Cursor's own agent loop. That means context-mode-enforcer (and any other Pi
# tool_call hook) cannot see or redirect them. A sampled Paseo Cursor session
# hit 509KB across 18 JSONL records using native webSearch/webFetch with zero
# bridged ctx_* calls.
#
# @cursor/sdk (1.0.27, vendored under pi-cursor-sdk) already supports
# `AgentOptions.tools: ToolName[]` to restrict the native toolset to `["mcp"]`
# (+ "askQuestion" so cursor_ask_question still works). pi-cursor-sdk 0.3.6
# does not expose or set this option. This patch adds it directly to the
# installed (compiled) dist file, matching the existing
# apply-pi-ask-user-label-patch.sh pattern for locally patching npm packages.
#
# Effect: once patched, Cursor local agents have no native shell/read/edit/
# search tools left. Cursor calls back through its MCP bridge for everything,
# which pi-cursor-sdk resolves against Pi's real active tool registry —
# including context-mode's ctx_execute/ctx_search/etc, and (when
# PI_CURSOR_EXPOSE_BUILTIN_TOOLS=1) Pi's read/bash/write/edit. Every one of
# those calls is a normal Pi tool_call event, so context-mode-enforcer applies
# to Cursor models exactly like it applies to every other provider.
#
# Escape hatch: PI_CURSOR_STRICT_MCP_ONLY=0 restores unrestricted native
# Cursor tools (pre-patch behavior) without reverting this patch.
#
# Idempotent; safe to run from setup/pi.sh and after a Pi update.
set -euo pipefail

TARGET="${PI_CURSOR_SDK_SESSION_AGENT_JS:-$HOME/.pi/agent/npm/node_modules/pi-cursor-sdk/dist/cursor-session-agent.js}"
MARKER="DOTFILES_PATCH: strict MCP-only tools"

if [[ ! -f "$TARGET" ]]; then
  echo "[pi-cursor-sdk-strict-mcp-patch] skip — not installed ($TARGET)"
  exit 0
fi

if grep -q "$MARKER" "$TARGET"; then
  echo "[pi-cursor-sdk-strict-mcp-patch] already applied"
  exit 0
fi

python3 - "$TARGET" "$MARKER" <<'PY'
import sys

path, marker = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()

helper = f"""
// {marker}
// Restrict Cursor local agents to MCP-only tools by default so every Cursor
// action is forced through pi-cursor-sdk's local MCP bridge (and therefore
// through Pi's tool_call event, where context-mode-enforcer can apply).
// Set PI_CURSOR_STRICT_MCP_ONLY=0 to restore native Cursor tools.
function dotfilesResolveCursorStrictMcpOnlyTools() {{
    const raw = (process.env.PI_CURSOR_STRICT_MCP_ONLY ?? "").trim().toLowerCase();
    const disabled = ["0", "false", "off", "no", "disabled"].includes(raw);
    if (disabled) return undefined;
    return ["mcp", "askQuestion"];
}}
"""

# Insert the helper once, right after the import block (before the first class/function).
anchor = 'class SessionCursorAgentCreationSupersededError extends Error {'
if anchor not in text:
    print("[pi-cursor-sdk-strict-mcp-patch] ERROR: import-block anchor not found — manual review needed", file=sys.stderr)
    sys.exit(1)
text = text.replace(anchor, helper.strip() + "\n" + anchor, 1)

old = """        const buildAgentOptions = () => ({
            apiKey: params.apiKey,
            model: params.modelSelection,
            mode: params.agentMode,
            local: buildCursorLocalAgentOptions({"""

new = """        const buildAgentOptions = () => ({
            apiKey: params.apiKey,
            model: params.modelSelection,
            mode: params.agentMode,
            tools: dotfilesResolveCursorStrictMcpOnlyTools(),
            local: buildCursorLocalAgentOptions({"""

if old not in text:
    print("[pi-cursor-sdk-strict-mcp-patch] ERROR: upstream buildAgentOptions block not found — manual review needed", file=sys.stderr)
    sys.exit(1)

text = text.replace(old, new, 1)
open(path, "w", encoding="utf-8").write(text)
print("[pi-cursor-sdk-strict-mcp-patch] applied — Cursor local agents now MCP-only by default (PI_CURSOR_STRICT_MCP_ONLY=0 to disable)")
PY
