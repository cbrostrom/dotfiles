#!/usr/bin/env bash
# pi-doctor — keep one healthy pi install and catch agents running an outdated build.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=pi-lib.sh
. "$ROOT/scripts/pi-lib.sh"

usage() {
    cat <<'EOF'
pi-doctor — check the canonical pi install (~/.npm-global)

  (default)   install present, bundle imports resolve, no duplicate copies,
              no running agents older than the install, paseo CLI matches daemon
  --smoke     also load the CLI (--help); slow
  --fix       reinstall pi into the canonical prefix, then pi update --all
  --prune     delete duplicate pi copies (refuses while outdated agents run)
EOF
}

SMOKE=0 FIX=0 PRUNE=0
for arg in "$@"; do
    case "$arg" in
        --smoke) SMOKE=1 ;;
        --fix) FIX=1 SMOKE=1 ;;
        --prune) PRUNE=1 ;;
        --quick) ;;
        -h | --help) usage; exit 0 ;;
        *) printf 'pi-doctor: unknown option: %s\n' "$arg" >&2; usage; exit 2 ;;
    esac
done

FAIL=0
log() { printf 'pi-doctor: %s\n' "$*"; }
warn() { printf 'pi-doctor: warning: %s\n' "$*" >&2; }
fail() { printf 'pi-doctor: error: %s\n' "$*" >&2; FAIL=1; }

if [[ $FIX -eq 1 ]]; then
    . "$ROOT/setup/lib.sh"
    activate_fnm
    log "installing $PI_PACKAGE into $PI_NPM_PREFIX"
    npm install -g --prefix "$PI_NPM_PREFIX" "$PI_PACKAGE"
    "$HOME/.local/bin/pi" update --all || warn "pi update --all failed"
fi

if ! pkg="$(pi_pkg_dir)"; then
    fail "pi is not installed — run: $ROOT/scripts/pi-doctor.sh --fix"
    exit 1
fi
log "pi $(jq -r .version "$pkg/package.json") at $pkg"
[[ "$pkg" == "$PI_NPM_PREFIX/"* ]] || warn "using a legacy fnm copy; run --fix to move pi to $PI_NPM_PREFIX"

# Every relative import between bundle chunks must exist on disk. A mismatch means
# a partial install, not a config problem.
if missing="$(node - "$pkg/dist/bundle/chunks" <<'NODE' 2>&1
const fs = require("fs"), path = require("path");
const dir = process.argv[2];
const re = /(?:from|import\s*\()\s*["']\.\/([^"']+)["']/g;
const missing = [];
for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".js"))) {
  const text = fs.readFileSync(path.join(dir, file), "utf8");
  for (const m of text.matchAll(re)) {
    if (!fs.existsSync(path.join(dir, m[1]))) missing.push(`${file} -> ./${m[1]}`);
  }
}
if (missing.length) { console.log(missing.slice(0, 10).join("\n")); process.exit(1); }
NODE
)"; then
    log "bundle imports: ok"
else
    fail "bundle imports point at missing files (partial install); run --fix"
    printf '%s\n' "$missing" >&2
fi

# Pi lazy-loads provider chunks, so a process started before the last update
# crashes the first time it touches a provider whose chunk was renamed.
install_epoch="$(stat -f %m "$pkg/package.json" 2>/dev/null || stat -c %Y "$pkg/package.json")"
stale="$(INSTALL_EPOCH="$install_epoch" node <<'NODE'
const { execFileSync } = require("child_process");
const since = Number(process.env.INSTALL_EPOCH) * 1000;
const rows = execFileSync("ps", ["-axo", "pid=,lstart=,command="], { encoding: "utf8" }).split("\n");
for (const row of rows) {
  const m = row.trim().match(/^(\d+)\s+(\w{3} \w{3}\s+\d+ [\d:]+ \d{4})\s+(.*)$/);
  if (!m) continue;
  const [, pid, start, cmd] = m;
  if (!/^pi(\s|$)|pi-rpc-interpreter|pi-coding-agent\/dist/.test(cmd)) continue;
  if (new Date(start).getTime() < since) console.log(`${pid}  started ${start}  ${cmd.slice(0, 60)}`);
}
NODE
)"
if [[ -n "$stale" ]]; then
    warn "these pi processes predate the installed build and can crash on their next provider switch; restart those Paseo agents:"
    printf '%s\n' "$stale" >&2
else
    log "running agents: all on the installed build"
fi

dupes=()
while IFS= read -r copy; do
    [[ -n "$copy" && "$copy" != "$pkg" ]] && dupes+=("$copy")
done < <(pi_fnm_copies)
legacy_local="$HOME/.local/lib/node_modules/$PI_PACKAGE"
[[ -d "$legacy_local" && "$legacy_local" != "$pkg" ]] && dupes+=("$legacy_local")
if [[ ${#dupes[@]} -gt 0 ]]; then
    if [[ $PRUNE -eq 1 && -z "$stale" ]]; then
        for copy in "${dupes[@]}"; do
            rm -rf "$copy"
            bin="$(dirname "$(dirname "$(dirname "$copy")")")/bin/pi"
            [[ -L "$bin" ]] && rm -f "$bin"
            log "pruned duplicate: $copy"
        done
    else
        warn "duplicate pi copies (updates may land in the wrong one):"
        printf '  %s\n' "${dupes[@]}" >&2
        [[ $PRUNE -eq 1 ]] && warn "not pruning while outdated agents run; restart them first"
        [[ $PRUNE -eq 0 ]] && log "remove with: $ROOT/scripts/pi-doctor.sh --prune"
    fi
fi

if command -v paseo >/dev/null 2>&1; then
    cli="$(paseo --version 2>/dev/null | tail -n 1)"
    daemon="$(paseo daemon status --json 2>/dev/null | jq -r '.daemonVersion // .version // empty' 2>/dev/null || true)"
    if [[ -n "$daemon" && "$cli" != "$daemon" ]]; then
        warn "paseo CLI $cli != daemon $daemon — run: npm i -g --prefix $PI_NPM_PREFIX @getpaseo/cli@$daemon"
    elif [[ -n "$daemon" ]]; then
        log "paseo CLI matches daemon ($daemon)"
    fi
fi

if [[ $SMOKE -eq 1 ]]; then
    if "$HOME/.local/bin/pi" --help >/dev/null 2>&1; then
        log "CLI load: ok"
    else
        fail "pi --help failed"
    fi
fi

[[ $FAIL -eq 0 ]] || { log "try: $ROOT/scripts/pi-doctor.sh --fix"; exit 1; }
log "ok"
