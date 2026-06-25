#!/usr/bin/env bash
command -v cargo >/dev/null 2>&1 || [[ -x "$HOME/.cargo/bin/cargo" ]] || exit 1
exit 0
