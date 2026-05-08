#!/usr/bin/env bash
MODULE_NAME="zed"
MODULE_DESC="Zed editor config (skipped on WSL — install on Windows side)"
MODULE_CATEGORY="editor"
# WSL excluded: Zed runs on Windows, not WSL.
MODULE_PLATFORMS="macos linux"
MODULE_PROFILES="desktop-full"
MODULE_CORE=false
MODULE_DEPENDS="symlinks"
MODULE_REQUIRES=""
MODULE_DEFAULT_ENABLED=true
