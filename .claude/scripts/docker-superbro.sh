#!/usr/bin/env bash
exec env DOCKER_HOST="ssh://superbro" npx -y mcp-server-docker
