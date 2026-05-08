#!/usr/bin/env bash
MODULE_NAME="fonts"
MODULE_DESC="Nerd Font (skipped on WSL — install on Windows side; skipped headless)"
# WSL excluded: fonts must be installed on the Windows side (no Linux GUI).
MODULE_PLATFORMS="macos linux"
MODULE_PROFILES="desktop-full"
MODULE_CORE=false
MODULE_DEPENDS=""
MODULE_REQUIRES="curl"
MODULE_DEFAULT_ENABLED=true
