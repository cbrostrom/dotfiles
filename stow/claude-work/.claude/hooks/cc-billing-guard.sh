#!/usr/bin/env bash
# UserPromptSubmit: fail closed unless this session bills the work claude.ai seat.
# Checked once per session. Escape hatch: CC_BILLING_GUARD_DISABLE=1
[[ "${CC_BILLING_GUARD_DISABLE:-}" == "1" ]] && exit 0
payload=$(cat)
sid=$(printf '%s' "$payload" | jq -r '.session_id // "nosession"' 2>/dev/null)
mkdir -p "${TMPDIR:-/tmp}/agent-hooks"
stamp="${TMPDIR:-/tmp}/agent-hooks/cc-billing-ok-$sid"
[[ -f "$stamp" ]] && exit 0
WORK_ORG="${CC_WORK_ORG:-AKQA Denmark}"
fail() { echo "[cc-guard] Billing guard: $1" >&2; exit 2; }
for v in ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY; do
  [[ -n "${!v:-}" ]] && fail "$v is set; unset it so the work seat is used."
done
method=$(claude auth status 2>/dev/null | jq -r '.authMethod // empty' 2>/dev/null)
[[ "$method" == "claude.ai" ]] || fail "login method is '${method:-unknown}', expected claude.ai (run /login)."
org=$(jq -r '.oauthAccount.organizationName // empty' "$HOME/.claude.json" 2>/dev/null)
[[ "$org" == "$WORK_ORG" ]] || fail "organisation is '${org:-unknown}', expected '$WORK_ORG'."
: >"$stamp"
exit 0
