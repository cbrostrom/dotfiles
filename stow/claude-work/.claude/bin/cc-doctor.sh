#!/usr/bin/env bash
# cc-doctor: verify Claude Code work-only / token / cost guards. Exit 1 on any FAIL.
S="$HOME/.claude/settings.json"; fail=0
ok(){ printf 'ok    %s\n' "$1"; }; bad(){ printf 'FAIL  %s\n' "$1"; fail=1; }
chk(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
org=$(jq -r '.oauthAccount.organizationName // ""' "$HOME/.claude.json" 2>/dev/null)
chk "org is ${CC_WORK_ORG:-AKQA Denmark} (got: $org)" '[ "$org" = "${CC_WORK_ORG:-AKQA Denmark}" ]'
chk "authMethod claude.ai" 'claude auth status 2>/dev/null | jq -e ".authMethod==\"claude.ai\""'
for v in ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY; do
  chk "$v unset" "[ -z \"\${$v:-}\" ]"; done
for kv in CLAUDE_CODE_DISABLE_1M_CONTEXT=0 CLAUDE_CODE_SUBAGENT_MODEL=haiku CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=1; do
  chk "env $kv" "jq -e --arg k ${kv%%=*} --arg v ${kv#*=} '.env[\$k]==\$v' $S"; done
chk "disableWorkflows" "jq -e '.disableWorkflows==true' $S"
chk "disableClaudeAiConnectors" "jq -e '.disableClaudeAiConnectors==true' $S"
chk "settings drift" "python3 $HOME/dotfiles/setup/claude-work/merge_settings.py $HOME/dotfiles/sources/claude-work/settings.json $S --check"
for h in work-scope-guard cc-billing-guard bash-guard guard-agent; do
  chk "hook $h wired" "grep -q $h $S"; done
chk "no prompt/agent hook types (settings+plugins)" "! grep -rEq '\"type\": *\"(prompt|agent)\"' $S $HOME/.claude/plugins/cache --include=settings.json --include=hooks.json"
mcp=$(claude mcp list 2>/dev/null | grep -E '^[^ ]+: ' | grep -v '^plugin:' )
chk "no MCP servers registered" '[ -z "$mcp" ]'
chk "context-mode plugin off" "jq -e '.enabledPlugins[\"context-mode@context-mode\"]!=true' $S"
chk "work mcporter servers only" "mcporter --config $HOME/.claude/mcporter/mcporter.json list 2>/dev/null | grep -q atlassian-agent-akqa && ! mcporter --config $HOME/.claude/mcporter/mcporter.json list 2>/dev/null | grep -Eq 'dockhand|cloudflare|higgins'"
chk "rtk present" 'command -v rtk'
if [ -t 1 ]; then echo "manual: run /usage and confirm no usage-credits row"; fi
exit $fail
