#!/usr/bin/env bash
exec env DOCKER_HOST="ssh://linuxbro" /home/christian/.local/bin/uvx mcp-server-docker
