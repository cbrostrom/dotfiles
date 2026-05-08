#!/usr/bin/env bash
command -v cargo >/dev/null 2>&1 || [[ -x "$HOME/.cargo/bin/cargo" ]] || exit 1
command -v lean-ctx >/dev/null 2>&1 || exit 1
exit 0
