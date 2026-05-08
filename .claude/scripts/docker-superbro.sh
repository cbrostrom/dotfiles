#!/usr/bin/env bash
exec env DOCKER_HOST="ssh://superbro" uvx mcp-server-docker
