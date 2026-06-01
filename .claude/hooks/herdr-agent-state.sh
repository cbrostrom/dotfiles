#!/usr/bin/env bash
# No-op on hosts without herdr. Real impl lives on Linux/WSL with herdr installed.
command -v herdr >/dev/null 2>&1 || exit 0
herdr agent-state "$1" 2>/dev/null || true
