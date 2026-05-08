#!/usr/bin/env bash
exec env DOCKER_HOST="ssh://linuxbro" npx -y mcp-server-docker
