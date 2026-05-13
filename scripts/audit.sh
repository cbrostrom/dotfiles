#!/usr/bin/env bash
# audit.sh — dotfiles cleanup audit. Read-only. No auto-fix.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

C0='\e[0m'
RED='\e[31m'
YEL='\e[33m'
CYN='\e[36m'
DIM='\e[2m'
BOLD='\e[1m'

[[ -t 1 ]] || { C0=''; RED=''; YEL=''; CYN=''; DIM=''; BOLD=''; }

_tag() { printf "${BOLD}[%-8s]${C0} %s\n" "$1" "$2"; }
_sep() { printf "${DIM}"; printf '%.0s─' {1..60}; printf "${C0}\n"; }

printf "\n${BOLD}${CYN}dotfiles audit${C0} — $(date '+%Y-%m-%d %H:%M')\n"
_sep

# ── 1. stale module refs in modules.conf ─────────────────────────────────────
printf "\n${BOLD}1. modules.conf refs${C0}\n"
if [[ -f "${DOTFILES_DIR}/modules.conf" ]]; then
  _found=0
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue
    local_name="${line#\!}"
    local_name="${local_name#"${local_name%%[![:space:]]*}"}"
    local_name="${local_name%"${local_name##*[![:space:]]}"}"
    if [[ ! -d "${DOTFILES_DIR}/modules/${local_name}" ]]; then
      _tag "stale" "modules.conf: '${line}' → no dir modules/${local_name}/"
      _found=1
    fi
  done < "${DOTFILES_DIR}/modules.conf"
  if (( _found == 0 )); then echo "  none"; fi
else
  echo "  modules.conf not found"
fi

# ── 2. disabled modules that still exist (cleanup candidates) ─────────────────
printf "\n${BOLD}2. disabled modules (exist but opted-out)${C0}\n"
_found=0
if [[ -f "${DOTFILES_DIR}/modules.conf" ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^\! ]] || continue
    local_name="${line#\!}"
    local_name="${local_name#"${local_name%%[![:space:]]*}"}"
    local_name="${local_name%"${local_name##*[![:space:]]}"}"
    if [[ -d "${DOTFILES_DIR}/modules/${local_name}" ]]; then
      _tag "unused" "!${local_name} — disabled in modules.conf but dir still present"
      _found=1
    fi
  done < "${DOTFILES_DIR}/modules.conf"
fi
if (( _found == 0 )); then echo "  none"; fi

# ── 3. zed-only code paths (zed is disabled via !zed) ─────────────────────────
printf "\n${BOLD}3. zed references outside zed module (zed is disabled)${C0}\n"
_found=0
while IFS= read -r f; do
  printf "${YEL}  %s${C0}\n" "$f"
  _found=1
done < <(grep -rlE --include="*.sh" --include="*.zsh" \
  '\bzed\b' "${DOTFILES_DIR}" 2>/dev/null \
  | grep -v '\.git' \
  | grep -v "${DOTFILES_DIR}/modules/zed/" \
  | grep -v "${DOTFILES_DIR}/scripts/zed/" \
  | grep -v "${DOTFILES_DIR}/tui/tools/zed.sh" \
  | grep -v "${BASH_SOURCE[0]}" \
  | sort)
if (( _found == 0 )); then echo "  none"; fi

# ── 4. dead symlinks on disk (targets missing) ────────────────────────────────
printf "\n${BOLD}4. broken symlinks on disk (~/)${C0}\n"
# Note: scanning up to maxdepth 5 — may be slow on large home dirs
_found=0
while IFS= read -r link; do
  [[ -e "$link" ]] && continue
  target="$(readlink "$link")"
  printf "${RED}  dead${C0}  %s → %s\n" "$link" "$target"
  _found=1
done < <(find "$HOME" -maxdepth 5 -type l 2>/dev/null)
if (( _found == 0 )); then echo "  none"; fi

# ── 5. potentially orphaned scripts ───────────────────────────────────────────
printf "\n${BOLD}5. potentially orphaned scripts in scripts/${C0}\n"
_found=0
while IFS= read -r script; do
  name="$(basename "$script")"
  callers="$(grep -rl --include="*.sh" --include="*.zsh" --include="*.md" \
    "$name" "${DOTFILES_DIR}" 2>/dev/null \
    | grep -v "^${script}$" \
    | grep -v '\.git' || true)"
  if [[ -z "$callers" ]]; then
    relative="${script#"${DOTFILES_DIR}/"}"
    _tag "maybe" "${relative} — no callers found (basename-only check)"
    _found=1
  fi
done < <(find "${DOTFILES_DIR}/scripts" -name "*.sh" -not -path '*/.git/*' 2>/dev/null | sort)
if (( _found == 0 )); then echo "  none"; fi

_sep
printf "${DIM}Audit complete. Read-only — no changes made.${C0}\n\n"
