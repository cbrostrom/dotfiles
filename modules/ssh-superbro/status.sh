#!/usr/bin/env bash
grep -q "Host superbro" "$HOME/.ssh/config" 2>/dev/null || exit 1
exit 0
