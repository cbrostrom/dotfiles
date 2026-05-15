#!/usr/bin/env bash
# Detect host platform. Output one of: darwin, linux, wsl.
#
# Module-local helper used by the SessionStart merge hook, which runs
# outside the bootstrap context and therefore cannot rely on
# modules/_lib/platform.sh. The output values (darwin/linux/wsl) match
# the filename suffixes used by the platform-tier overlay JSON files.
detect_platform() {
    case "$(uname -s)" in
        Darwin) echo "darwin" ;;
        Linux)
            if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        *) echo "linux" ;;  # safe headless fallback
    esac
}

# Cross-platform stat mtime (epoch seconds).
mtime() {
    stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}
