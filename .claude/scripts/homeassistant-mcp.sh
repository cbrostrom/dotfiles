#!/bin/bash
# Home Assistant MCP — proxies linuxbro HA instance via Tailscale
# Requires HA_MCP_TOKEN in ~/.local-secrets

source ~/.local-secrets 2>/dev/null

exec npx -y mcp-remote http://100.100.1.100:8123/api/mcp \
  --header "Authorization: Bearer ${HA_MCP_TOKEN}"
