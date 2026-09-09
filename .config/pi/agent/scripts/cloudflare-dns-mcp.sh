#!/bin/zsh
# Wrapper: sources local secrets (CLOUDFLARE_API_TOKEN) then execs the MCP server.
# CLOUDFLARE_ZONE_ID is passed in via mcp.json's per-server "env" block (not secret).
# llmtrim sets HTTP(S)_PROXY=127.0.0.1:43117; that proxy breaks TLS to
# api.cloudflare.com / registry.npmjs.org and hangs Pi MCP connect (~35s).
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy
source ~/.local-secrets
exec npx -y @thelord/mcp-cloudflare
