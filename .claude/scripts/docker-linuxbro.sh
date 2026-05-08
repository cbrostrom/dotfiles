#!/usr/bin/env bash
exec env DOCKER_HOST="ssh://linuxbro" uvx mcp-server-docker
