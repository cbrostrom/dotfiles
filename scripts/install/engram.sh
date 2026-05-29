#!/usr/bin/env bash
# =============================================================================
# scripts/install/engram.sh — install engram binary + initialise vault git repo
# =============================================================================
# Idempotent. Run on each machine after cloning dotfiles.
#
# What this does:
#   1) Check/install engram binary via `go install`
#   2) Init vault dir as a git repo (if not already)
#   3) Add .gitignore (exclude live DB; track chunk files only)
#   4) Set git remote (git@github.com:cbrostrom/engram.git)
#
# Platform notes:
#   WSL     — binary must be installed from Windows PowerShell, not WSL.
#             This script prints instructions and skips binary install.
#             Vault at %USERPROFILE%\.engram (= /mnt/c/Users/<user>/.engram from WSL).
#   macOS   — go install runs natively; binary at ~/go/bin/engram.
#   Linux   — go install runs natively; binary at ~/go/bin/engram.
#
# Background sync (optional, separate from Claude Code hooks):
#   macOS   : launchd agent via modules/engram/dk.brostrom.engram-sync.plist
#   Linux   : systemd-user units via modules/engram/engram-sync.{service,timer,path}
#   WSL     : systemd requires /etc/wsl.conf [boot] systemd=true
# =============================================================================

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
GIT_REMOTE="git@github.com:cbrostrom/engram.git"
ENGRAM_PKG="github.com/Gentleman-Programming/engram/cmd/engram@latest"

# ── colour helpers ──────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    ok()   { echo -e "\033[32m ✓\033[0m $*"; }
    log()  { echo -e "\033[34m →\033[0m $*"; }
    warn() { echo -e "\033[33m !\033[0m $*"; }
    info() { echo    "   $*"; }
else
    ok()   { echo "OK: $*"; }
    log()  { echo "→  $*"; }
    warn() { echo "!  $*"; }
    info() { echo "   $*"; }
fi

# ── platform detection ───────────────────────────────────────────────────────
IS_WSL=false
IS_MACOS=false
if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
elif [[ "$(uname -s)" == "Darwin" ]]; then
    IS_MACOS=true
fi

# ── vault path per platform ──────────────────────────────────────────────────
if $IS_WSL; then
    WIN_HOME="/mnt/c/Users/${USER}"
    SYNC_REPO="${WIN_HOME}/.engram"
else
    SYNC_REPO="${HOME}/.engram"
fi
# Vault = personal sub-vault within the sync repo
VAULT_DIR="${SYNC_REPO}/personal"

# ── 1) binary ────────────────────────────────────────────────────────────────
install_binary() {
    if $IS_WSL; then
        warn "WSL detected — engram binary must be installed from Windows PowerShell."
        info "Run in PowerShell:  go install ${ENGRAM_PKG}"
        info "Binary lands at:   %USERPROFILE%\\go\\bin\\engram.exe"
        info "Skipping binary install here (this is the Linux side)."
        return 0
    fi

    if command -v engram >/dev/null 2>&1; then
        ok "engram already on PATH: $(command -v engram) ($(engram version 2>/dev/null | head -1))"
        return 0
    fi

    if ! command -v go >/dev/null 2>&1; then
        warn "go not found — install Go first: https://go.dev/dl/"
        warn "Then rerun: bash ${DOTFILES_DIR}/scripts/install/engram.sh"
        return 1
    fi

    log "Installing engram via go install …"
    go install "${ENGRAM_PKG}"

    if command -v engram >/dev/null 2>&1; then
        ok "engram installed: $(command -v engram) ($(engram version 2>/dev/null | head -1))"
    else
        warn "engram not found after install — ensure $(go env GOPATH)/bin is on PATH"
    fi
}

# ── 2) sync repo + vault dirs init ──────────────────────────────────────────
init_vault() {
    # sync repo = parent dir; vault subdirs live inside it
    mkdir -p "${SYNC_REPO}/personal" "${SYNC_REPO}/work"

    # .gitignore at sync repo root — exclude live DBs, track only chunks
    local gitignore="${SYNC_REPO}/.gitignore"
    if [[ ! -f "${gitignore}" ]]; then
        cat > "${gitignore}" <<'EOF'
# SQLite ephemera — never sync
*.db-wal
*.db-shm
*.db-journal
*.db
*.sqlite
*.sqlite3

# Lock files / temp
*.lock
.DS_Store
.tmp/
*.tmp

# Sync local state
.last-sync
sync.log
EOF
        ok "Created ${gitignore}"
    else
        ok ".gitignore already present"
    fi

    # .gitattributes — force LF for cross-platform consistency
    local gitattrs="${SYNC_REPO}/.gitattributes"
    if [[ ! -f "${gitattrs}" ]]; then
        echo '* text=auto eol=lf' > "${gitattrs}"
        ok "Created ${gitattrs}"
    fi

    if [[ -d "${SYNC_REPO}/.git" ]]; then
        ok "Sync repo already initialised: ${SYNC_REPO}"
    else
        log "Initialising git repo: ${SYNC_REPO} …"
        # safe.directory needed on WSL (NTFS mount shows 0777 perms)
        git config --global --add safe.directory "${SYNC_REPO}" 2>/dev/null || true
        git -C "${SYNC_REPO}" init -b main >/dev/null
        ok "git init done"
    fi

    # remote
    local current_remote
    current_remote="$(git -C "${SYNC_REPO}" remote get-url origin 2>/dev/null || echo "")"
    if [[ -z "${current_remote}" ]]; then
        git -C "${SYNC_REPO}" remote add origin "${GIT_REMOTE}"
        ok "Remote set: ${GIT_REMOTE}"
    elif [[ "${current_remote}" != "${GIT_REMOTE}" ]]; then
        warn "Remote mismatch (got: ${current_remote}, expected: ${GIT_REMOTE}) — leaving as-is"
    else
        ok "Remote already set: ${GIT_REMOTE}"
    fi

    # initial commit if empty (pull first if remote exists)
    if [[ -z "$(git -C "${SYNC_REPO}" log --oneline 2>/dev/null | head -1)" ]]; then
        git -C "${SYNC_REPO}" fetch origin main 2>/dev/null \
            && git -C "${SYNC_REPO}" reset --hard origin/main \
            && ok "Pulled existing sync history from remote" \
            || {
                git -C "${SYNC_REPO}" add .gitignore .gitattributes
                git -C "${SYNC_REPO}" commit -m "chore: init engram vault sync repo" --quiet
                ok "Initial commit created"
            }
    fi
}

# ── 3) background sync scheduler (optional) ─────────────────────────────────
install_scheduler() {
    local sync_sh="${DOTFILES_DIR}/modules/engram/sync.sh"
    [[ -f "${sync_sh}" ]] || { warn "sync.sh not found, skipping scheduler setup"; return 0; }
    chmod +x "${sync_sh}"

    if $IS_MACOS; then
        local plist_src="${DOTFILES_DIR}/modules/engram/dk.brostrom.engram-sync.plist"
        local plist_dst="${HOME}/Library/LaunchAgents/dk.brostrom.engram-sync.plist"
        [[ -f "${plist_src}" ]] || { warn "plist not found, skipping launchd setup"; return 0; }
        mkdir -p "$(dirname "${plist_dst}")" "${HOME}/Library/Logs"
        sed -e "s#__HOME__#${HOME}#g" -e "s#__SYNC_SH__#${sync_sh}#g" \
            "${plist_src}" > "${plist_dst}"
        launchctl unload "${plist_dst}" 2>/dev/null || true
        launchctl load "${plist_dst}" && ok "LaunchAgent loaded" || warn "launchctl load failed"

    elif $IS_WSL; then
        warn "WSL: systemd scheduler requires [boot] systemd=true in /etc/wsl.conf"
        warn "     After enabling: rerun this script to install systemd units."
        if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
            _install_systemd "${sync_sh}"
        else
            info "Skipping systemd setup (not available)."
        fi

    else
        _install_systemd "${sync_sh}"
    fi
}

_install_systemd() {
    local sync_sh="$1"
    local unit_src="${DOTFILES_DIR}/modules/engram"
    local unit_dst="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
    mkdir -p "${unit_dst}"
    for unit in engram-sync.service engram-sync.timer engram-sync.path; do
        [[ -f "${unit_src}/${unit}" ]] || continue
        sed "s#__SYNC_SH__#${sync_sh}#g" "${unit_src}/${unit}" > "${unit_dst}/${unit}"
    done
    systemctl --user daemon-reload
    systemctl --user enable --now engram-sync.timer engram-sync.path 2>/dev/null \
        && ok "systemd-user units enabled" \
        || warn "systemd enable failed"
}

# ── summary ───────────────────────────────────────────────────────────────────
print_summary() {
    echo ""
    log "Engram setup complete"
    info "sync repo: ${SYNC_REPO}  (git-tracked, chunks only)"
    info "vault:     ${VAULT_DIR}  (live SQLite, gitignored)"
    info "remote:    ${GIT_REMOTE}"
    if $IS_WSL; then
        info "binary:    /mnt/c/Users/\${USER}/go/bin/engram.exe  (install from PowerShell)"
    else
        info "binary:    $(command -v engram 2>/dev/null || echo 'not found — ensure ~/go/bin on PATH')"
    fi
    echo ""
    info "First push:   git -C ${SYNC_REPO} push -u origin main"
    info "Manual sync:  ENGRAM_DATA_DIR=${VAULT_DIR} engram sync"
}

# ── main ──────────────────────────────────────────────────────────────────────
install_binary
init_vault
install_scheduler
print_summary
