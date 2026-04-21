#!/usr/bin/env bash
# install.sh — thin shim that delegates to bootstrap.sh
# Kept for backward compatibility with `dotfiles.sh` and existing muscle memory.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bootstrap.sh" "$@"
