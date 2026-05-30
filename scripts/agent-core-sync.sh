#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CLAUDE_DIR="${CLAUDE_DIR:-$DOTFILES_DIR/.claude}"
CURSOR_DIR="${CURSOR_DIR:-$HOME/.cursor}"
AGENT_CORE_FILE="${AGENT_CORE_FILE:-$CLAUDE_DIR/agent-core.json}"

QUIET=0
if [[ "${1:-}" == "--quiet" ]]; then
    QUIET=1
fi

log() {
    if [[ "$QUIET" -ne 1 ]]; then
        printf '%s\n' "$*"
    fi
}

if [[ ! -f "$AGENT_CORE_FILE" ]]; then
    log "[agent-core-sync] missing $AGENT_CORE_FILE (skip)"
    exit 0
fi

if [[ ! -f "$CURSOR_DIR/cli-config.json" && ! -d "$CURSOR_DIR" ]]; then
    log "[agent-core-sync] cursor not installed ($CURSOR_DIR missing) (skip)"
    exit 0
fi

# shellcheck source=modules/_lib/lists.sh
source "$DOTFILES_DIR/modules/_lib/lists.sh"

mkdir -p "$CURSOR_DIR"

model_id="$(jq -r '.model.cursor_model_id // empty' "$AGENT_CORE_FILE")"
display_name="$(jq -r '.model.display_name // empty' "$AGENT_CORE_FILE")"
aliases_json="$(jq -c '.model.aliases // []' "$AGENT_CORE_FILE")"
language="$(jq -r '.language // "english"' "$AGENT_CORE_FILE")"
cursor_defaults_json="$(jq -c '.cursor.defaults // {}' "$AGENT_CORE_FILE")"
mcp_base_rel="$(jq -r '.mcp.base_list // ".claude/mcp-servers.list"' "$AGENT_CORE_FILE")"

if [[ -z "$model_id" ]]; then
    echo "[agent-core-sync] model.cursor_model_id missing in $AGENT_CORE_FILE" >&2
    exit 1
fi
if [[ -z "$display_name" ]]; then
    display_name="$model_id"
fi

mcp_base="$DOTFILES_DIR/$mcp_base_rel"
if [[ ! -f "$mcp_base" ]]; then
    echo "[agent-core-sync] MCP list not found: $mcp_base" >&2
    exit 1
fi

servers='{}'
while IFS='|' read -r name command args_rest || [[ -n "${name:-}" ]]; do
    name="$(echo "${name:-}" | xargs)"
    [[ -z "$name" ]] && continue

    command="$(echo "${command:-}" | xargs)"
    command="${command/#\~/$HOME}"
    [[ -z "$command" ]] && continue

    IFS='|' read -ra raw_args <<< "${args_rest:-}"
    args=()
    for t in "${raw_args[@]+"${raw_args[@]}"}"; do
        t="$(echo "$t" | xargs)"
        [[ -n "$t" ]] && args+=("$t")
    done

    if [[ "$command" == "http" ]]; then
        [[ "${#args[@]}" -lt 1 ]] && continue
        url="${args[0]}"
        servers="$(jq -c --arg n "$name" --arg u "$url" '. + {($n): {url: $u}}' <<<"$servers")"
    else
        args_json="$(jq -nc --args '$ARGS.positional' -- "${args[@]+"${args[@]}"}")"
        servers="$(jq -c --arg n "$name" --arg c "$command" --argjson a "$args_json" '. + {($n): {command: $c, args: $a}}' <<<"$servers")"
    fi
done < <(lists_merge "$mcp_base")

tmp_mcp="$(mktemp "$CURSOR_DIR/mcp.json.XXXXXX")"
jq -n --argjson s "$servers" '{mcpServers: $s}' > "$tmp_mcp"
mv "$tmp_mcp" "$CURSOR_DIR/mcp.json"
log "[agent-core-sync] wrote $CURSOR_DIR/mcp.json"

cli_config="$CURSOR_DIR/cli-config.json"
if [[ ! -f "$cli_config" ]]; then
    printf '%s\n' '{}' > "$cli_config"
fi

tmp_cli="$(mktemp "$CURSOR_DIR/cli-config.json.XXXXXX")"
jq \
  --arg model "$model_id" \
  --arg display "$display_name" \
  --arg lang "$language" \
  --argjson aliases "$aliases_json" \
  --argjson defaults "$cursor_defaults_json" \
  '
  def set_if_present(path; key):
    if ($defaults | has(key)) then
      setpath(path; $defaults[key])
    else
      .
    end;

  .version = (.version // 1)
  | .hasChangedDefaultModel = true
  | .model = ((.model // {}) + {
      modelId: $model,
      displayModelId: $model,
      displayName: $display,
      displayNameShort: $display,
      aliases: (((.model.aliases // []) + $aliases) | map(select(type == "string" and length > 0)) | unique)
    })
  | .selectedModel = {modelId: $model, parameters: []}
  | .modelParameters = ((.modelParameters // {}) + {($model): []})
  | .language = $lang
  | .editor = (.editor // {})
  | .sandbox = (.sandbox // {})
  | set_if_present(["approvalMode"]; "approvalMode")
  | set_if_present(["notifications"]; "notifications")
  | set_if_present(["hints"]; "hints")
  | set_if_present(["suggestNextPrompt"]; "suggestNextPrompt")
  | set_if_present(["rewind"]; "rewind")
  | set_if_present(["editor", "vimMode"]; "vimMode")
  | set_if_present(["sandbox", "mode"]; "sandboxMode")
  | set_if_present(["sandbox", "networkAccess"]; "sandboxNetworkAccess")
  ' "$cli_config" > "$tmp_cli"
mv "$tmp_cli" "$cli_config"
log "[agent-core-sync] wrote $cli_config"

exit 0
