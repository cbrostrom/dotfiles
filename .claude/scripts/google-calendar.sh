#!/usr/bin/env bash
set -euo pipefail
export GOOGLE_OAUTH_CREDENTIALS="$HOME/.config/google-calendar-mcp/gcp-oauth.keys.json"
export GOOGLE_CALENDAR_MCP_TOKEN_PATH="$HOME/.config/google-calendar-mcp/tokens.json"
exec npx -y @cocal/google-calendar-mcp
