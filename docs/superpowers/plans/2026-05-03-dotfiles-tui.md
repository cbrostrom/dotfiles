# Dotfiles TUI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `dotfiles.sh` fzf-menu with a gum-based TUI showing status always visible above an action menu, with categorized tools submenus.

**Architecture:** `dotfiles.sh` becomes a thin entry point that checks for gum, renders status + menu, and delegates to `tui/*.sh` scripts. The tui scripts are pure UI wrappers — they call existing scripts in `scripts/` and `bootstrap.sh` rather than re-implementing logic.

**Tech Stack:** bash, gum (Charmbracelet), existing dotfiles scripts

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `dotfiles.sh` | **Rewrite** | Entry point: gum check, main loop, routing |
| `tui/status.sh` | **Create** | Status checks + formatted gum output |
| `tui/update.sh` | **Create** | git pull + scripts with gum spin |
| `tui/install.sh` | **Create** | Guided wizard for fresh machine |
| `tui/tools/zed.sh` | **Create** | Zed submenu: merge/diff/promote |
| `tui/tools/symlinks.sh` | **Create** | Symlinks submenu |
| `tui/tools/fonts.sh` | **Create** | Font install |
| `tui/tools/secrets.sh` | **Create** | Secrets check/display |
| `Brewfile` | **Modify** | Add gum |
| `scripts/install/debian.sh` | **Modify** | Add gum to apt packages |

---

## Task 1: Create tui/ structure + gum detection in dotfiles.sh

**Files:**
- Create: `tui/status.sh` (empty scaffold)
- Create: `tui/update.sh` (empty scaffold)
- Create: `tui/install.sh` (empty scaffold)
- Create: `tui/tools/zed.sh` (empty scaffold)
- Create: `tui/tools/symlinks.sh` (empty scaffold)
- Create: `tui/tools/fonts.sh` (empty scaffold)
- Create: `tui/tools/secrets.sh` (empty scaffold)
- Modify: `dotfiles.sh`

- [ ] **Create tui/ directory scaffolds**

```bash
mkdir -p /home/christian/.config/dotfiles/tui/tools
for f in tui/status.sh tui/update.sh tui/install.sh tui/tools/zed.sh tui/tools/symlinks.sh tui/tools/fonts.sh tui/tools/secrets.sh; do
  printf '#!/usr/bin/env bash\nset -euo pipefail\n\nDOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"\n' \
    > /home/christian/.config/dotfiles/$f
  chmod +x /home/christian/.config/dotfiles/$f
done
# tools/ scripts need to go up one more level
for f in tui/tools/zed.sh tui/tools/symlinks.sh tui/tools/fonts.sh tui/tools/secrets.sh; do
  printf '#!/usr/bin/env bash\nset -euo pipefail\n\nDOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"\n' \
    > /home/christian/.config/dotfiles/$f
done
```

- [ ] **Rewrite dotfiles.sh with gum detection and skeleton main loop**

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

source "$DOTFILES_DIR/tui/status.sh"
source "$DOTFILES_DIR/tui/update.sh"
source "$DOTFILES_DIR/tui/install.sh"

# --- gum detection ---
ensure_gum() {
    command -v gum >/dev/null 2>&1 && return 0
    echo "gum not found — required for this TUI."
    if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        echo "Install via: brew install gum"
        read -rp "Auto-install now? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] && brew install gum && return 0
    elif [[ -f /etc/debian_version ]]; then
        echo "Install via: sudo apt install gum"
        read -rp "Auto-install now? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] && sudo apt install -y gum && return 0
    fi
    echo "Please install gum and re-run. Exiting."
    exit 1
}

# --- main loop ---
main() {
    ensure_gum

    while true; do
        clear
        show_status   # from tui/status.sh — prints status block

        ACTION=$(gum choose \
            "Install / Setup" \
            "Update" \
            "Tools" \
            "Quit" \
            --header "ACTIONS" \
            --cursor "› " \
            2>/dev/null) || break

        case "$ACTION" in
            "Install / Setup") run_install ;;   # tui/install.sh
            "Update")          run_update ;;    # tui/update.sh
            "Tools")           run_tools ;;     # inline below
            "Quit"|"")         break ;;
        esac
    done
}

run_tools() {
    CATEGORY=$(gum choose \
        "Zed" \
        "Symlinks" \
        "Fonts" \
        "Secrets" \
        "← Back" \
        --header "TOOLS" 2>/dev/null) || return

    case "$CATEGORY" in
        "Zed")      bash "$DOTFILES_DIR/tui/tools/zed.sh" ;;
        "Symlinks") bash "$DOTFILES_DIR/tui/tools/symlinks.sh" ;;
        "Fonts")    bash "$DOTFILES_DIR/tui/tools/fonts.sh" ;;
        "Secrets")  bash "$DOTFILES_DIR/tui/tools/secrets.sh" ;;
        "← Back"|"") return ;;
    esac
}

main "$@"
```

- [ ] **Verify dotfiles.sh is executable and starts without error (gum must be installed)**

```bash
which gum || echo "install gum first: brew install gum / sudo apt install gum"
bash -n /home/christian/.config/dotfiles/dotfiles.sh  # syntax check only
```

- [ ] **Commit**

```bash
git -C /home/christian/.config/dotfiles add dotfiles.sh tui/
git -C /home/christian/.config/dotfiles commit -m "feat(tui): scaffold tui/ structure and rewrite dotfiles.sh entry point"
```

---

## Task 2: Status module (tui/status.sh)

**Files:**
- Modify: `tui/status.sh`

The status module checks the same things as `doctor.sh` but formats output with `gum style` for display in the main loop. It exports a single function `show_status` that dotfiles.sh calls.

- [ ] **Write tui/status.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Returns "ok", "warn", or "fail"
_check_symlink() {
    local target="$1"
    [[ -L "$target" ]] && echo "ok" || { [[ -e "$target" ]] && echo "warn" || echo "fail"; }
}

_check_zed() {
    local zed_dir
    if [[ "$(uname -s)" == "Darwin" ]]; then
        zed_dir="$HOME/Library/Application Support/Zed"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        local win_user="${USERNAME:-$(whoami)}"
        zed_dir="/mnt/c/Users/$win_user/AppData/Roaming/Zed"
    else
        zed_dir="$HOME/.config/zed"
    fi
    [[ -L "$zed_dir/settings.json" ]] && echo "ok" || echo "fail"
}

_check_secrets() {
    [[ -f "$HOME/.local-secrets" ]] || { echo "fail"; return; }
    local perms
    perms=$(stat -L -c '%a' "$HOME/.local-secrets" 2>/dev/null || stat -L -f '%Lp' "$HOME/.local-secrets" 2>/dev/null)
    [[ "$perms" == "600" ]] && echo "ok" || echo "warn"
}

_check_node() {
    command -v node >/dev/null 2>&1 && echo "ok" || echo "fail"
}

_check_git() {
    git config --global user.email >/dev/null 2>&1 && echo "ok" || echo "warn"
}

_last_update() {
    local fetch_head="$DOTFILES_DIR/.git/FETCH_HEAD"
    if [[ -f "$fetch_head" ]]; then
        local ts now diff
        ts=$(stat -c '%Y' "$fetch_head" 2>/dev/null || stat -f '%m' "$fetch_head" 2>/dev/null)
        now=$(date +%s)
        diff=$(( (now - ts) / 86400 ))
        echo "${diff}d ago"
    else
        echo "never"
    fi
}

_badge() {
    local status="$1" label="$2" detail="$3"
    case "$status" in
        ok)   gum style --foreground 10  "  ✓ $(printf '%-14s' "$label") $detail" ;;
        warn) gum style --foreground 11  "  ⚠ $(printf '%-14s' "$label") $detail" ;;
        fail) gum style --foreground 9   "  ✗ $(printf '%-14s' "$label") $detail" ;;
    esac
}

show_status() {
    local zsh_st git_st zed_st sec_st node_st
    zsh_st=$(_check_symlink "$HOME/.zshrc")
    git_st=$(_check_git)
    zed_st=$(_check_zed)
    sec_st=$(_check_secrets)
    node_st=$(_check_node)
    local last
    last=$(_last_update)

    gum style --bold --foreground 220 "STATUS"
    _badge "$zsh_st"  "zsh"     "$(  [[ $zsh_st  == ok ]] && echo linked   || echo "not linked")"
    _badge "$git_st"  "git"     "$(  [[ $git_st  == ok ]] && echo configured || echo "check gitconfig")"
    _badge "$zed_st"  "zed"     "$(  [[ $zed_st  == ok ]] && echo synced   || echo "not synced")"
    _badge "$sec_st"  "secrets" "$(  [[ $sec_st  == ok ]] && echo ok        || { [[ $sec_st == warn ]] && echo "bad perms" || echo "missing"; })"
    _badge "$node_st" "node"    "$(  command -v node >/dev/null 2>&1 && node --version 2>/dev/null || echo "not found")"
    gum style --foreground 8 "  last update: $last"
    echo
}

# Allow standalone run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    ensure_gum 2>/dev/null || true
    show_status
fi
```

- [ ] **Test show_status standalone**

```bash
bash /home/christian/.config/dotfiles/tui/status.sh
# Expected: colored status lines for zsh, git, zed, secrets, node
```

- [ ] **Commit**

```bash
git -C /home/christian/.config/dotfiles add tui/status.sh
git -C /home/christian/.config/dotfiles commit -m "feat(tui): add status module with gum-styled output"
```

---

## Task 3: Update flow (tui/update.sh)

**Files:**
- Modify: `tui/update.sh`

Wraps `bootstrap.sh --update` steps individually so each gets a spinner.

- [ ] **Write tui/update.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_update() {
    echo
    gum style --bold --foreground 220 "UPDATE"
    echo

    local failed=()

    _spin() {
        local title="$1"; shift
        if gum spin --title "$title" -- "$@"; then
            gum style --foreground 10 "  ✓ $title"
        else
            gum style --foreground 9  "  ✗ $title"
            failed+=("$title")
        fi
    }

    _spin "Pulling latest from git" \
        git -C "$DOTFILES_DIR" pull --rebase --autostash

    _spin "Updating symlinks" \
        bash "$DOTFILES_DIR/scripts/install/symlinks.sh"

    _spin "Merging Zed settings" \
        bash "$DOTFILES_DIR/scripts/zed/zed-update-local.sh"

    _spin "Running doctor" \
        bash "$DOTFILES_DIR/scripts/doctor.sh" 2>/dev/null

    echo
    if [[ ${#failed[@]} -eq 0 ]]; then
        gum style --foreground 10 --bold "All done."
    else
        gum style --foreground 9 --bold "Completed with issues:"
        for f in "${failed[@]}"; do
            gum style --foreground 9 "  • $f"
        done
    fi
    echo
    read -rsp "Press any key to return…" -n1
}

# Allow standalone run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_update
fi
```

- [ ] **Test update standalone (dry — verify it runs without destroying anything)**

```bash
bash -n /home/christian/.config/dotfiles/tui/update.sh  # syntax check
# Manual test: bash /home/christian/.config/dotfiles/tui/update.sh
```

- [ ] **Commit**

```bash
git -C /home/christian/.config/dotfiles add tui/update.sh
git -C /home/christian/.config/dotfiles commit -m "feat(tui): add update flow with gum spin per step"
```

---

## Task 4: Install wizard (tui/install.sh)

**Files:**
- Modify: `tui/install.sh`

Multi-select wizard that calls bootstrap.sh with appropriate flags.

- [ ] **Write tui/install.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_install() {
    echo
    gum style --bold --foreground 220 "INSTALL / SETUP"

    # Detect OS for display
    local profile="unknown"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        profile="macOS / desktop-full"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        profile="WSL / wsl"
    elif [[ -f /etc/debian_version ]]; then
        profile="Linux / desktop-full"
    fi
    gum style --foreground 8 "  Detected: $profile"
    echo

    # Build component list based on OS
    local opts=("Packages (brew / apt)" "Symlinks" "Fonts" "Zed config")
    [[ "$(uname -s)" == "Darwin" ]] && opts+=("macOS defaults")

    mapfile -t SELECTED < <(
        gum choose --no-limit \
            --header "Select components to install:" \
            --selected "Symlinks,Zed config" \
            "${opts[@]}" 2>/dev/null
    )

    [[ ${#SELECTED[@]} -eq 0 ]] && { echo "Nothing selected."; return; }

    echo
    gum style --foreground 8 "Will install:"
    for s in "${SELECTED[@]}"; do
        gum style --foreground 8 "  • $s"
    done
    echo

    gum confirm "Run selected steps?" 2>/dev/null || return

    local failed=()

    _spin() {
        local title="$1"; shift
        if gum spin --title "$title" -- "$@"; then
            gum style --foreground 10 "  ✓ $title"
        else
            gum style --foreground 9  "  ✗ $title"
            failed+=("$title")
        fi
    }

    for step in "${SELECTED[@]}"; do
        case "$step" in
            "Packages (brew / apt)")
                _spin "Installing packages" bash "$DOTFILES_DIR/bootstrap.sh" --packages-only ;;
            "Symlinks")
                _spin "Creating symlinks" bash "$DOTFILES_DIR/scripts/install/symlinks.sh" ;;
            "Fonts")
                _spin "Installing fonts" bash "$DOTFILES_DIR/scripts/install/nerd-fonts.sh" ;;
            "Zed config")
                _spin "Setting up Zed" bash "$DOTFILES_DIR/scripts/zed/install-zed-config.sh" ;;
            "macOS defaults")
                _spin "Applying macOS defaults" bash "$DOTFILES_DIR/macos/defaults.sh" ;;
        esac
    done

    echo
    if [[ ${#failed[@]} -eq 0 ]]; then
        gum style --foreground 10 --bold "Setup complete."
    else
        gum style --foreground 9 --bold "Completed with issues:"
        for f in "${failed[@]}"; do gum style --foreground 9 "  • $f"; done
    fi
    echo
    read -rsp "Press any key to return…" -n1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_install
fi
```

- [ ] **Syntax check**

```bash
bash -n /home/christian/.config/dotfiles/tui/install.sh
```

- [ ] **Commit**

```bash
git -C /home/christian/.config/dotfiles add tui/install.sh
git -C /home/christian/.config/dotfiles commit -m "feat(tui): add install wizard with gum multi-select"
```

---

## Task 5: Zed tools (tui/tools/zed.sh)

**Files:**
- Modify: `tui/tools/zed.sh`

- [ ] **Write tui/tools/zed.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

ACTION=$(gum choose \
    "Merge settings (base → local)" \
    "Diff base vs local" \
    "Promote change to base" \
    "← Back" \
    --header "TOOLS › ZED" 2>/dev/null) || exit 0

case "$ACTION" in
    "Merge settings (base → local)")
        gum spin --title "Merging Zed settings…" -- \
            bash "$DOTFILES_DIR/scripts/zed/zed-update-local.sh"
        gum style --foreground 10 "Done."
        read -rsp "Press any key…" -n1
        ;;
    "Diff base vs local")
        echo
        bash "$DOTFILES_DIR/scripts/zed/zed-diff-base.sh" | less -R
        ;;
    "Promote change to base")
        echo
        gum style --foreground 11 "Steps to promote a local change to base:"
        gum style --foreground 8  "  1. Review diff below"
        gum style --foreground 8  "  2. Edit .config/zed/settings.base.json"
        gum style --foreground 8  "  3. git commit + push"
        gum style --foreground 8  "  4. Other machines pick up on next update"
        echo
        bash "$DOTFILES_DIR/scripts/zed/zed-diff-base.sh" | less -R
        ;;
    "← Back"|"") exit 0 ;;
esac
```

- [ ] **Syntax check**

```bash
bash -n /home/christian/.config/dotfiles/tui/tools/zed.sh
```

- [ ] **Commit**

```bash
git -C /home/christian/.config/dotfiles add tui/tools/zed.sh
git -C /home/christian/.config/dotfiles commit -m "feat(tui): add Zed tools submenu"
```

---

## Task 6: Remaining tools (symlinks, fonts, secrets)

**Files:**
- Modify: `tui/tools/symlinks.sh`
- Modify: `tui/tools/fonts.sh`
- Modify: `tui/tools/secrets.sh`

- [ ] **Write tui/tools/symlinks.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

ACTION=$(gum choose \
    "Re-link all" \
    "Force update symlinks" \
    "Check status" \
    "← Back" \
    --header "TOOLS › SYMLINKS" 2>/dev/null) || exit 0

case "$ACTION" in
    "Re-link all")
        gum spin --title "Re-linking…" -- \
            bash "$DOTFILES_DIR/scripts/install/symlinks.sh"
        gum style --foreground 10 "Done."
        read -rsp "Press any key…" -n1
        ;;
    "Force update symlinks")
        gum confirm "Force-update will recreate all symlinks. Continue?" 2>/dev/null || exit 0
        gum spin --title "Force-updating…" -- \
            bash "$DOTFILES_DIR/force-update-symlinks.sh"
        gum style --foreground 10 "Done."
        read -rsp "Press any key…" -n1
        ;;
    "Check status")
        echo
        bash "$DOTFILES_DIR/scripts/doctor.sh" 2>/dev/null | less -R
        ;;
    "← Back"|"") exit 0 ;;
esac
```

- [ ] **Write tui/tools/fonts.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

gum confirm "Install / reinstall Nerd Fonts?" 2>/dev/null || exit 0
gum spin --title "Installing Nerd Fonts…" -- \
    bash "$DOTFILES_DIR/scripts/install/nerd-fonts.sh"
gum style --foreground 10 "Done."
read -rsp "Press any key…" -n1
```

- [ ] **Write tui/tools/secrets.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo
gum style --bold --foreground 220 "TOOLS › SECRETS"
echo

SECRETS_FILE="$HOME/.local-secrets"

if [[ ! -f "$SECRETS_FILE" ]]; then
    gum style --foreground 9 "  ✗ ~/.local-secrets not found"
    gum style --foreground 8 "  Copy from: $DOTFILES_DIR/.local-secrets.example"
    echo
    read -rsp "Press any key…" -n1
    exit 0
fi

# Check permissions
local_perms=$(stat -L -c '%a' "$SECRETS_FILE" 2>/dev/null || stat -L -f '%Lp' "$SECRETS_FILE" 2>/dev/null)
if [[ "$local_perms" == "600" ]]; then
    gum style --foreground 10 "  ✓ Permissions: 600 (correct)"
else
    gum style --foreground 9 "  ✗ Permissions: $local_perms (should be 600)"
    gum confirm "Fix permissions now?" 2>/dev/null && chmod 600 "$SECRETS_FILE" && \
        gum style --foreground 10 "  ✓ Fixed."
fi

echo
gum style --foreground 8 "  Defined keys (values hidden):"
grep -E '^[A-Z_]+=.' "$SECRETS_FILE" 2>/dev/null | \
    sed 's/=.*/=***/' | \
    while read -r line; do
        gum style --foreground 8 "    $line"
    done

echo
read -rsp "Press any key…" -n1
```

- [ ] **Syntax check all three**

```bash
bash -n /home/christian/.config/dotfiles/tui/tools/symlinks.sh
bash -n /home/christian/.config/dotfiles/tui/tools/fonts.sh
bash -n /home/christian/.config/dotfiles/tui/tools/secrets.sh
```

- [ ] **Commit**

```bash
git -C /home/christian/.config/dotfiles add tui/tools/
git -C /home/christian/.config/dotfiles commit -m "feat(tui): add symlinks, fonts, secrets tool submenus"
```

---

## Task 7: Add gum to package managers

**Files:**
- Modify: `Brewfile`
- Modify: `scripts/install/debian.sh`

- [ ] **Add gum to Brewfile**

Open `Brewfile` and add after the existing brew entries:

```ruby
brew "gum"
```

- [ ] **Add gum to debian.sh**

Find the apt package install block in `scripts/install/debian.sh` and add `gum` to the list. gum is available via the Charmbracelet apt repo — add the repo setup if not already present:

```bash
# In scripts/install/debian.sh, add gum installation:
if ! command -v gum >/dev/null 2>&1; then
    log_info "Installing gum..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
        | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt update && sudo apt install -y gum
fi
```

- [ ] **Syntax check debian.sh**

```bash
bash -n /home/christian/.config/dotfiles/scripts/install/debian.sh
```

- [ ] **Commit**

```bash
git -C /home/christian/.config/dotfiles add Brewfile scripts/install/debian.sh
git -C /home/christian/.config/dotfiles commit -m "chore: add gum to Brewfile and debian package installer"
```

---

## Task 8: End-to-end smoke test + push

- [ ] **Install gum if not already installed**

```bash
# macOS:
brew install gum
# Debian/WSL:
# sudo apt install gum  (or use the repo setup from Task 7)
```

- [ ] **Run dotfiles command and verify main screen appears**

```bash
bash /home/christian/.config/dotfiles/dotfiles.sh
# Expected: STATUS panel + ACTIONS menu renders without errors
# Navigate: ↑↓, select Update, verify spinner runs, press q to quit
```

- [ ] **Test each Tools submenu item navigates without errors**

```bash
# From dotfiles command: Tools → Zed → Diff base vs local (should show diff or "no diff")
# From dotfiles command: Tools → Secrets (should show key list)
# From dotfiles command: Tools → Symlinks → Check status
```

- [ ] **Verify dotfiles alias still works (if configured)**

```bash
grep -r "dotfiles" /home/christian/.config/dotfiles/zsh/ | grep alias
# If alias exists, verify it points to the right place
```

- [ ] **Push**

```bash
git -C /home/christian/.config/dotfiles push
```
