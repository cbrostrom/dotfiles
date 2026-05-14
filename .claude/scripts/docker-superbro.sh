#!/usr/bin/env bash
UVX="${UVX:-$(command -v uvx || echo "$HOME/.local/bin/uvx")}"
exec env DOCKER_HOST="ssh://superbro" "$UVX" --with paramiko mcp-server-docker
