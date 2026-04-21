#!/usr/bin/env bash
# =============================================================================
# macos/defaults.sh — opinionated macOS system preferences
# =============================================================================
# Idempotent. Apply with: ./macos/defaults.sh
# Each block is annotated; comment out anything you disagree with.
# =============================================================================

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Skipping macOS defaults — not on Darwin." >&2
    exit 0
fi

log() { printf "\033[0;34m[defaults]\033[0m %s\n" "$*"; }

log "Asking for sudo upfront…"
sudo -v

# -----------------------------------------------------------------------------
# Keyboard — fast key repeat (Tahoe-friendly)
# -----------------------------------------------------------------------------
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# -----------------------------------------------------------------------------
# Finder — show hidden, extensions, status bar
# -----------------------------------------------------------------------------
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# -----------------------------------------------------------------------------
# Screenshots → ~/Screenshots/, PNG, no shadows
# -----------------------------------------------------------------------------
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# -----------------------------------------------------------------------------
# Dock — minimal, fast, no recents
# -----------------------------------------------------------------------------
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.4
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock mineffect -string "scale"

# -----------------------------------------------------------------------------
# Trackpad — tap to click
# -----------------------------------------------------------------------------
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# -----------------------------------------------------------------------------
# Safari & Quick Look — dev-friendly
# -----------------------------------------------------------------------------
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true 2>/dev/null || true
defaults write com.apple.Safari IncludeDevelopMenu -bool true 2>/dev/null || true

# -----------------------------------------------------------------------------
# Touch ID for sudo (Tahoe 26 ships /etc/pam.d/sudo_local.template)
# -----------------------------------------------------------------------------
if [[ -f /etc/pam.d/sudo_local.template && ! -f /etc/pam.d/sudo_local ]]; then
    log "Enabling Touch ID for sudo…"
    sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
    sudo sed -i '' 's/^#auth/auth/' /etc/pam.d/sudo_local
fi

# -----------------------------------------------------------------------------
# Rosetta (Apple Silicon only)
# -----------------------------------------------------------------------------
if [[ "$(uname -m)" == "arm64" ]] && ! /usr/bin/pgrep -q oahd; then
    log "Installing Rosetta 2…"
    sudo softwareupdate --install-rosetta --agree-to-license || true
fi

# -----------------------------------------------------------------------------
# Restart affected services
# -----------------------------------------------------------------------------
for app in Finder Dock SystemUIServer; do
    killall "$app" 2>/dev/null || true
done

log "Done. Some changes require logout/restart."
