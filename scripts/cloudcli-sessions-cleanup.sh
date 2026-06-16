#!/usr/bin/env bash
set -euo pipefail

# Purge CloudCLI session index + transcript files.
#
# Archive-only cleanup does NOT stick: the session watcher rescans
# ~/.claude/projects, ~/.cursor/projects, etc. and createSession() sets
# isArchived=0 on every upsert. Use purge (delete DB rows + jsonl files).

readonly DATABASE_PATH="${CLOUDCLI_DATABASE_PATH:-$HOME/.cloudcli/auth.db}"
readonly PM2_PROCESS="${CLOUDCLI_PM2_PROCESS:-cloudcli-ui}"

usage() {
  cat <<'EOF'
Usage: cloudcli-sessions-cleanup.sh <command> [options]

Commands:
  status                 Show active/archived session counts
  list [--limit N]       List recent sessions (default limit: 20)
  purge                  Delete sessions from DB and disk (see options)
  install-launchd        Install daily 5-day retention LaunchAgent (macOS)

Purge options:
  --all                  Remove every session row (default without filters)
  --older-than DAYS      Remove sessions older than N days
  --keep N               Keep N most recent per project; purge the rest
  --provider NAME        Only claude|cursor|codex|gemini|opencode
  --include-archived       Also target archived rows
  --dry-run              Print what would be deleted
  --yes                  Skip confirmation prompt
  --no-restart           Do not restart cloudcli-ui via pm2 after purge

Examples:
  cloudcli-sessions-cleanup.sh status
  cloudcli-sessions-cleanup.sh purge --keep 5 --dry-run
  cloudcli-sessions purge --older-than 14 --yes
  cloudcli-sessions purge --all --yes
  cloudcli-sessions install-launchd   # daily purge of sessions >5 days
EOF
}

die() {
  echo "cloudcli-sessions-cleanup: $*" >&2
  exit 1
}

require_db() {
  [[ -f "$DATABASE_PATH" ]] || die "database not found at $DATABASE_PATH"
  command -v sqlite3 >/dev/null 2>&1 || die "sqlite3 is required"
}

sql() {
  sqlite3 -separator $'\t' -noheader "$DATABASE_PATH" "$1"
}

pm2_running() {
  command -v pm2 >/dev/null 2>&1 && pm2 pid "$PM2_PROCESS" >/dev/null 2>&1
}

restart_cloudcli() {
  if [[ "${NO_RESTART:-0}" == 1 ]]; then
    return 0
  fi
  if pm2_running; then
    echo "restarting $PM2_PROCESS..."
    pm2 restart "$PM2_PROCESS" >/dev/null
  fi
}

cmd_status() {
  require_db
  local active archived
  active=$(sql "SELECT COUNT(*) FROM sessions WHERE isArchived = 0;")
  archived=$(sql "SELECT COUNT(*) FROM sessions WHERE isArchived = 1;")
  echo "database: $DATABASE_PATH"
  echo "active:   $active"
  echo "archived: $archived"
  echo
  echo "by provider (active):"
  sqlite3 -column -header "$DATABASE_PATH" \
    "SELECT provider, COUNT(*) AS count FROM sessions WHERE isArchived = 0 GROUP BY provider ORDER BY count DESC;"
}

cmd_list() {
  require_db
  local limit="${1:-20}"
  sqlite3 -column -header "$DATABASE_PATH" "
    SELECT provider,
           substr(COALESCE(custom_name, session_id), 1, 40) AS title,
           substr(COALESCE(project_path, ''), 1, 50) AS project,
           COALESCE(updated_at, created_at) AS updated,
           CASE isArchived WHEN 1 THEN 'archived' ELSE 'active' END AS state
    FROM sessions
    ORDER BY datetime(COALESCE(updated_at, created_at)) DESC
    LIMIT $limit;
  "
}

build_purge_query() {
  local where="1=1"

  if [[ "${INCLUDE_ARCHIVED:-0}" != 1 ]]; then
    where+=" AND isArchived = 0"
  fi

  if [[ -n "${PROVIDER:-}" ]]; then
    where+=" AND provider = '$(printf '%s' "$PROVIDER" | sed "s/'/''/g")'"
  fi

  if [[ -n "${OLDER_THAN_DAYS:-}" ]]; then
    where+=" AND datetime(COALESCE(updated_at, created_at)) < datetime('now', '-${OLDER_THAN_DAYS} days')"
  fi

  if [[ -n "${KEEP_PER_PROJECT:-}" ]]; then
    cat <<SQL
WITH ranked AS (
  SELECT session_id, jsonl_path,
         ROW_NUMBER() OVER (
           PARTITION BY COALESCE(project_path, '')
           ORDER BY datetime(COALESCE(updated_at, created_at)) DESC, session_id DESC
         ) AS rn
  FROM sessions
  WHERE $where
)
SELECT session_id, COALESCE(jsonl_path, '') FROM ranked WHERE rn > ${KEEP_PER_PROJECT};
SQL
    return
  fi

  if [[ "${PURGE_ALL:-0}" != 1 && -z "${OLDER_THAN_DAYS:-}" ]]; then
    die "purge requires --all, --older-than DAYS, or --keep N"
  fi

  echo "SELECT session_id, COALESCE(jsonl_path, '') FROM sessions WHERE $where;"
}

cmd_purge() {
  require_db

  PURGE_ALL=0
  OLDER_THAN_DAYS=""
  KEEP_PER_PROJECT=""
  PROVIDER=""
  INCLUDE_ARCHIVED=0
  DRY_RUN=0
  ASSUME_YES=0
  NO_RESTART=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all) PURGE_ALL=1; shift ;;
      --older-than) OLDER_THAN_DAYS="${2:-}"; [[ -n "$OLDER_THAN_DAYS" ]] || die "--older-than needs a number"; shift 2 ;;
      --keep) KEEP_PER_PROJECT="${2:-}"; [[ -n "$KEEP_PER_PROJECT" ]] || die "--keep needs a number"; shift 2 ;;
      --provider) PROVIDER="${2:-}"; [[ -n "$PROVIDER" ]] || die "--provider needs a value"; shift 2 ;;
      --include-archived) INCLUDE_ARCHIVED=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      --yes|-y) ASSUME_YES=1; shift ;;
      --no-restart) NO_RESTART=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown purge option: $1" ;;
    esac
  done

  local query
  query=$(build_purge_query)

  local -a rows=()
  local row
  while IFS= read -r row; do
    [[ -n "$row" ]] && rows+=("$row")
  done < <(sql "$query")
  local count=${#rows[@]}

  if [[ "$count" -eq 0 ]]; then
    echo "nothing to purge"
    exit 0
  fi

  echo "sessions to purge: $count"
  if [[ "$DRY_RUN" == 1 ]]; then
    local shown=0
    for row in "${rows[@]}"; do
      IFS=$'\t' read -r session_id jsonl_path <<<"$row"
      echo "  $session_id  ${jsonl_path:-<no jsonl>}"
      shown=$((shown + 1))
      [[ "$shown" -lt 15 ]] || { echo "  ... and $((count - shown)) more"; break; }
    done
    exit 0
  fi

  if [[ "$ASSUME_YES" != 1 ]]; then
    echo "This permanently deletes $count CloudCLI sessions and their transcript files."
    echo "Archive-only cleanup will not work — the watcher re-imports from disk."
    read -r -p "Type 'purge' to continue: " answer
    [[ "$answer" == "purge" ]] || die "aborted"
  fi

  if pm2_running; then
    echo "stopping $PM2_PROCESS to avoid resync races..."
    pm2 stop "$PM2_PROCESS" >/dev/null
    local stopped_pm2=1
  else
    local stopped_pm2=0
  fi

  local deleted_files=0
  local missing_files=0
  local session_ids=()

  for row in "${rows[@]}"; do
    IFS=$'\t' read -r session_id jsonl_path <<<"$row"
    session_ids+=("$session_id")
    if [[ -n "$jsonl_path" && -f "$jsonl_path" ]]; then
      rm -f "$jsonl_path"
      deleted_files=$((deleted_files + 1))
    elif [[ -n "$jsonl_path" ]]; then
      missing_files=$((missing_files + 1))
    fi
  done

  local sid escaped
  for sid in "${session_ids[@]}"; do
    escaped="${sid//\'/\'\'}"
    sql "DELETE FROM sessions WHERE session_id = '$escaped';"
  done

  echo "purged sessions: $count"
  echo "deleted transcript files: $deleted_files"
  echo "missing transcript files: $missing_files"

  if [[ "$stopped_pm2" == 1 ]]; then
    echo "starting $PM2_PROCESS..."
    pm2 start "$PM2_PROCESS" >/dev/null 2>&1 || pm2 restart "$PM2_PROCESS" >/dev/null
  else
    restart_cloudcli
  fi
}

cmd_install_launchd() {
  [[ "$(uname -s)" == "Darwin" ]] || die "install-launchd: macOS only"

  local dotfiles_dir="${DOTFILES_DIR:-$HOME/dotfiles}"
  local plist_src="${dotfiles_dir}/macos/launchagents/dk.brostrom.cloudcli-sessions.plist"
  local plist_dst="${HOME}/Library/LaunchAgents/dk.brostrom.cloudcli-sessions.plist"
  local script="${dotfiles_dir}/scripts/cloudcli-sessions-cleanup.sh"

  [[ -f "$plist_src" ]] || die "plist not found: $plist_src"
  [[ -x "$script" ]] || chmod +x "$script"

  mkdir -p "${HOME}/Library/LaunchAgents" "${HOME}/Library/Logs"
  sed -e "s|__DOTFILES_DIR__|${dotfiles_dir}|g" \
      -e "s|__HOME__|${HOME}|g" \
      "$plist_src" > "$plist_dst"

  launchctl bootout "gui/$(id -u)/dk.brostrom.cloudcli-sessions" 2>/dev/null \
    || launchctl unload "$plist_dst" 2>/dev/null \
    || true
  launchctl bootstrap "gui/$(id -u)" "$plist_dst" 2>/dev/null \
    || launchctl load "$plist_dst"

  echo "installed LaunchAgent → $plist_dst"
  echo "schedule: daily 04:00, purge sessions older than 5 days"
  echo "logs: ~/Library/Logs/cloudcli-sessions-cleanup.log"
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    status) cmd_status "$@" ;;
    list)
      local limit=20
      [[ "${1:-}" == "--limit" && -n "${2:-}" ]] && limit="$2"
      cmd_list "$limit"
      ;;
    purge) cmd_purge "$@" ;;
    install-launchd) cmd_install_launchd "$@" ;;
    -h|--help|help|"") usage ;;
    *) die "unknown command: $cmd (run without args for help)" ;;
  esac
}

main "$@"
