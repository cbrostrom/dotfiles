#!/usr/bin/env bash
# Update the configured dotfiles fleet over key-only SSH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLEET_CONF="$DOTFILES_DIR/config/fleet-hosts.conf"
REMOTE_HELPER="$SCRIPT_DIR/fleet-apply.sh"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/fleet"
SSH_OPTIONS=(
    -o BatchMode=yes
    -o ConnectTimeout=8
    -o ServerAliveInterval=15
    -o ServerAliveCountMax=2
)

usage() {
    cat <<'EOF'
Usage: ./scripts/system/fleet-update.sh [--all] [--host NAME ...]
       ./scripts/system/fleet-update.sh --list

Updates every host in FLEET_DOTFILES_HOSTS by default. Each remote run refuses
local Git changes, fast-forwards only, plans Stow, installs its profile, applies
an optional setup/hosts/<name>.sh hook, and runs scripts/doctor.sh.

Options:
  --all          Update every configured dotfiles target (default)
  --host NAME    Update one target; repeat to select several
  --list         Print configured targets without contacting them
  -h, --help     Show this help

Notifications:
  Failures print a summary and trigger a macOS desktop notification. To use a
  different channel, set DOTFILES_FLEET_NOTIFY_CMD to an executable. It receives
  three arguments: status, summary, and run log directory.
EOF
}

[[ -f "$FLEET_CONF" ]] || {
    printf 'error: fleet config missing: %s\n' "$FLEET_CONF" >&2
    exit 1
}
[[ -f "$REMOTE_HELPER" ]] || {
    printf 'error: remote helper missing: %s\n' "$REMOTE_HELPER" >&2
    exit 1
}

# shellcheck source=config/fleet-hosts.conf
source "$FLEET_CONF"
: "${FLEET_DOTFILES_HOSTS:?FLEET_DOTFILES_HOSTS is not configured in $FLEET_CONF}"

selected=()
list_only=false
while (($#)); do
    case "$1" in
        --all)
            selected=()
            ;;
        --host)
            [[ $# -ge 2 ]] || {
                printf 'error: --host requires a name\n' >&2
                exit 2
            }
            selected+=("$2")
            shift
            ;;
        --list)
            list_only=true
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            printf 'error: unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

((${#selected[@]})) || selected=("${FLEET_DOTFILES_HOSTS[@]}")

lookup_profile() {
    local wanted="$1" entry name _address _port _user profile _role _push _paseo _notes
    for entry in "${FLEET_SSH[@]}"; do
        IFS='|' read -r name _address _port _user profile _role _push _paseo _notes <<<"$entry"
        if [[ "$name" == "$wanted" ]]; then
            printf '%s\n' "$profile"
            return 0
        fi
    done
    return 1
}

validate_targets() {
    local host profile seen="|"
    for host in "${selected[@]}"; do
        [[ "$host" =~ ^[a-zA-Z0-9._-]+$ ]] || {
            printf 'error: invalid fleet host name: %s\n' "$host" >&2
            return 2
        }
        [[ "$host" != "mac" ]] || {
            printf 'error: mac is the control plane; update it locally\n' >&2
            return 2
        }
        [[ "$seen" != *"|$host|"* ]] || {
            printf 'error: duplicate fleet target: %s\n' "$host" >&2
            return 2
        }
        seen+="$host|"
        profile="$(lookup_profile "$host")" || {
            printf 'error: fleet target is not defined in FLEET_SSH: %s\n' "$host" >&2
            return 2
        }
        [[ -f "$DOTFILES_DIR/profiles/$profile.stow" ]] || {
            printf 'error: %s references unknown profile: %s\n' "$host" "$profile" >&2
            return 2
        }
    done
}
validate_targets

if [[ "$list_only" == true ]]; then
    for host in "${selected[@]}"; do
        printf '%-16s %s\n' "$host" "$(lookup_profile "$host")"
    done
    exit 0
fi

run_id="$(date '+%Y%m%d-%H%M%S')-$$"
run_dir="$STATE_ROOT/$run_id"
mkdir -p "$run_dir"

hosts=()
statuses=()
stages=()
logs=()
failures=0

for host in "${selected[@]}"; do
    profile="$(lookup_profile "$host")"
    log_file="$run_dir/$host.log"
    printf '\n=== %s (%s) ===\n' "$host" "$profile"

    printf -v remote_command 'bash -s -- %q %q' "$host" "$profile"
    set +e
    # host/profile are allowlisted above and shell-escaped with printf %q.
    # shellcheck disable=SC2029
    ssh "${SSH_OPTIONS[@]}" "$host" \
        "$remote_command" <"$REMOTE_HELPER" 2>&1 | tee "$log_file"
    ssh_status=${PIPESTATUS[0]}
    set -e

    result_line="$(awk -F'|' '/^FLEET_RESULT\|/ { line=$0 } END { print line }' "$log_file")"
    status="failed:$ssh_status"
    stage="ssh"
    if [[ -n "$result_line" ]]; then
        IFS='|' read -r _marker _result_host status stage _old _new _result_profile <<<"$result_line"
    elif [[ $ssh_status -eq 255 ]]; then
        status="unreachable"
    fi

    hosts+=("$host")
    statuses+=("$status")
    stages+=("$stage")
    logs+=("$log_file")
    if [[ "$status" != "ok" ]]; then
        ((failures += 1))
    fi
done

printf '\n%-16s %-14s %-16s %s\n' HOST STATUS STAGE LOG
printf '%-16s %-14s %-16s %s\n' '----------------' '--------------' '----------------' '---'
for ((i = 0; i < ${#hosts[@]}; i++)); do
    printf '%-16s %-14s %-16s %s\n' \
        "${hosts[$i]}" "${statuses[$i]}" "${stages[$i]}" "${logs[$i]}"
done

notify_failure() {
    local summary="$1" notifier="${DOTFILES_FLEET_NOTIFY_CMD:-}"
    if [[ -n "$notifier" ]]; then
        if [[ -x "$notifier" ]]; then
            "$notifier" failure "$summary" "$run_dir" || \
                printf 'warning: fleet notifier failed: %s\n' "$notifier" >&2
        else
            printf 'warning: DOTFILES_FLEET_NOTIFY_CMD is not executable: %s\n' "$notifier" >&2
        fi
        return
    fi

    if [[ "$(uname -s)" == "Darwin" ]] && command -v osascript >/dev/null 2>&1; then
        osascript - "$summary" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
    display notification (item 1 of argv) with title "Dotfiles fleet update failed"
end run
APPLESCRIPT
    fi
}

if ((failures)); then
    failed_hosts=()
    for ((i = 0; i < ${#hosts[@]}; i++)); do
        [[ "${statuses[$i]}" == "ok" ]] || failed_hosts+=("${hosts[$i]} (${stages[$i]})")
    done
    summary="$failures of ${#hosts[@]} failed: ${failed_hosts[*]}"
    printf '\nerror: %s\n' "$summary" >&2
    notify_failure "$summary"
    exit 1
fi

printf '\nall %d fleet hosts updated successfully\n' "${#hosts[@]}"
