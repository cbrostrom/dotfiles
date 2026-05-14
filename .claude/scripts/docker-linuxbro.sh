#!/usr/bin/env bash
UVX="${UVX:-$(command -v uvx || echo "$HOME/.local/bin/uvx")}"
exec env DOCKER_HOST="ssh://linuxbro" "$UVX" --with paramiko mcp-server-docker
