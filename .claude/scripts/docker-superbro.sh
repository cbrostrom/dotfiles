#!/usr/bin/env bash
exec env DOCKER_HOST="ssh://superbro" /home/christian/.local/bin/uvx mcp-server-docker
