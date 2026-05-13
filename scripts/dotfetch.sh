#!/usr/bin/env bash
# dotfetch — neofetch-style dotfiles info display
set -euo pipefail

DOTFETCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── colors ────────────────────────────────────────────────────────────────────
_df_setup_colors() {
  if [[ -t 1 ]]; then
    C0='\e[0m'
    C1='\e[36m'
    BOLD='\e[1m'
    DIM='\e[2m'
  else
    C0=''; C1=''; BOLD=''; DIM=''
  fi
}

# ── ascii art ─────────────────────────────────────────────────────────────────
# Width: ~20 cols. Height: 12 lines.
_df_ascii() {
  ART=(
    "      /\\_____/\\"
    "     /  o   o  \\"
    "    ( ==  ^  == )"
    "     )         ("
    "    (           )"
    "     \\  |   |  /"
    "      \\_|___|_/"
    "                    "
    "  ╔════════════╗  "
    "  ║  BROWOLFF  ║  "
    "  ╚════════════╝  "
    "                    "
  )
}

# ── stat collectors ───────────────────────────────────────────────────────────

_df_get_os() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    local name version
    name="$(sw_vers -productName 2>/dev/null || echo macOS)"
    version="$(sw_vers -productVersion 2>/dev/null || echo '')"
    echo "${name} ${version}"
  elif [[ -f /etc/os-release ]]; then
    local name
    name="$(. /etc/os-release && echo "${PRETTY_NAME:-${NAME:-Linux}}")"
    echo "${name} $(uname -m)"
  else
    echo "$(uname -s) $(uname -m)"
  fi
}

_df_get_kernel() {
  uname -r
}

_df_get_uptime() {
  if [[ -f /proc/uptime ]]; then
    local secs
    secs="$(cut -d. -f1 /proc/uptime)"
    local days=$(( secs / 86400 ))
    local hours=$(( (secs % 86400) / 3600 ))
    local mins=$(( (secs % 3600) / 60 ))
    if (( days > 0 )); then echo "${days}d ${hours}h ${mins}m"
    elif (( hours > 0 )); then echo "${hours}h ${mins}m"
    else echo "${mins}m"
    fi
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    local boot now secs
    boot="$(sysctl -n kern.boottime 2>/dev/null | awk '{print $4}' | tr -d ',')"
    now="$(date +%s)"
    secs=$(( now - boot ))
    local days=$(( secs / 86400 ))
    local hours=$(( (secs % 86400) / 3600 ))
    local mins=$(( (secs % 3600) / 60 ))
    if (( days > 0 )); then echo "${days}d ${hours}h ${mins}m"
    elif (( hours > 0 )); then echo "${hours}h ${mins}m"
    else echo "${mins}m"
    fi
  else
    echo "unknown"
  fi
}

_df_get_shell() {
  local shell_name
  shell_name="$(basename "${SHELL:-bash}")"
  case "$shell_name" in
    zsh)  echo "zsh ${ZSH_VERSION:-}";;
    bash) echo "bash ${BASH_VERSION:-}";;
    *)    echo "$shell_name";;
  esac
}

_df_get_terminal() {
  echo "${TERM_PROGRAM:-${TERM:-unknown}}"
}

_df_get_version() {
  local vfile="${DOTFETCH_DIR}/VERSION"
  [[ -f "$vfile" ]] && cat "$vfile" || echo "unknown"
}

_df_get_branch() {
  local branch dirty
  branch="$(git -C "$DOTFETCH_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  if git -C "$DOTFETCH_DIR" status --porcelain 2>/dev/null | grep -q .; then
    dirty=' ✗'
  else
    dirty=' ✓'
  fi
  echo "${branch}${dirty}"
}

_df_get_modules() {
  local total disabled enabled
  total=0
  for d in "${DOTFETCH_DIR}/modules"/*/; do
    [[ -f "${d}module.sh" ]] || continue
    (( total++ ))
  done
  disabled=0
  if [[ -f "${DOTFETCH_DIR}/modules.conf" ]]; then
    disabled="$(grep -c '^!' "${DOTFETCH_DIR}/modules.conf" 2>/dev/null || echo 0)"
  fi
  enabled=$(( total - disabled ))
  echo "${enabled} / ${total} enabled"
}

_df_get_symlinks_fast() {
  local count
  count="$(grep -c 'create_symlink' "${DOTFETCH_DIR}/scripts/install/symlinks.sh" 2>/dev/null || echo '?')"
  echo "${count} defined"
}

_df_get_symlinks_full() {
  local total=0 broken=0
  while IFS= read -r target; do
    [[ -L "$target" ]] || continue
    (( total++ ))
    [[ -e "$target" ]] || (( broken++ )) || true
  done < <(find "$HOME" -maxdepth 4 -type l 2>/dev/null)
  echo "${total} total  ${broken} broken"
}

# ── renderer ──────────────────────────────────────────────────────────────────
# Uses global ART array set by _df_ascii — no bash nameref (macOS bash 3.2 compat)

_df_render() {
  local -a stats=("$@")
  local art_width=22
  local art_len=${#ART[@]}
  local stats_len=${#stats[@]}
  local max=$(( art_len > stats_len ? art_len : stats_len ))

  for (( i=0; i<max; i++ )); do
    local art_line="${ART[$i]:-}"
    local stat_line="${stats[$i]:-}"
    local padded
    padded="$(printf "%-${art_width}s" "$art_line")"
    printf "${C1}%s${C0}  %s\n" "$padded" "$stat_line"
  done
}

# ── color swatch ──────────────────────────────────────────────────────────────

_df_swatch() {
  [[ -t 1 ]] || return 0
  printf '\n%22s' ''
  for i in {0..7}; do printf "\e[4${i}m   \e[0m"; done
  printf '\n%22s' ''
  for i in {0..7}; do printf "\e[10${i}m   \e[0m"; done
  printf '\n\n'
}

# ── main ──────────────────────────────────────────────────────────────────────

main() {
  local mode="fast"
  for arg in "$@"; do
    case "$arg" in
      --full)  mode="full";;
      --audit) exec bash "${DOTFETCH_DIR}/scripts/audit.sh"; exit;;
      --help|-h)
        echo "Usage: dotfetch [--full] [--audit]"
        echo "  --full   include broken symlink scan (slower)"
        echo "  --audit  run cleanup audit"
        exit 0;;
    esac
  done

  _df_setup_colors
  _df_ascii

  local os kernel uptime shell terminal version branch modules symlinks
  os="$(_df_get_os)"
  kernel="$(_df_get_kernel)"
  uptime="$(_df_get_uptime)"
  shell="$(_df_get_shell)"
  terminal="$(_df_get_terminal)"
  version="$(_df_get_version)"
  branch="$(_df_get_branch)"
  modules="$(_df_get_modules)"
  if [[ "$mode" == "full" ]]; then
    symlinks="$(_df_get_symlinks_full)"
  else
    symlinks="$(_df_get_symlinks_fast)"
  fi

  local user_host sep
  user_host="${BOLD}${USER:-$(whoami)}@${HOSTNAME:-$(hostname -s)}${C0}"
  sep="${DIM}$(printf '%.0s─' {1..36})${C0}"

  local -a stats=(
    "$user_host"
    "$sep"
    "${C1}OS${C0}       ${os}"
    "${C1}Kernel${C0}   ${kernel}"
    "${C1}Uptime${C0}   ${uptime}"
    "${C1}Shell${C0}    ${shell}"
    "${C1}Terminal${C0} ${terminal}"
    ""
    "${DIM}── dotfiles $(printf '%.0s─' {1..18})${C0}"
    "${C1}Version${C0}  ${version}"
    "${C1}Branch${C0}   ${branch}"
    "${C1}Modules${C0}  ${modules}"
    "${C1}Symlinks${C0} ${symlinks}"
  )

  printf '\n'
  _df_render "${stats[@]}"
  _df_swatch
}

main "$@"
