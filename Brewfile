# Brewfile — macOS only (mac / Macbook = AKQABro)
# Install-only. NEVER run `brew bundle cleanup`: the machine has more installed
# than is listed here by design, and cleanup would uninstall it.
#
# Trim policy:
#   - Removed 13 unused taps (no formula referenced).
#   - Removed entire "library deps" section: those are transitive deps
#     of imagemagick / llama.cpp / qemu / docker / etc. brew bundle cleanup
#     does NOT remove formulae that are deps of installed parents, so
#     explicit pinning was unnecessary noise.
#   - Removed zellij (unused).
#   - Removed casks dbgate, dotnet-sdk, syncthing-app, voicemod
#     (not installed on current host; re-add if needed elsewhere).
#
# FIXME comments mark personal-choice duplicates (e.g. 3 prompts, 2 node
# version managers, 3 python versions). Pick one and drop the rest.

# =============================================================================
# Taps
# =============================================================================
tap "muhammadhananasghar/tap"        # wormhole
tap "oven-sh/bun"                    # bun (not yet in homebrew core)
tap "yoanbernabeu/tap"               # grepai

# =============================================================================
# Core CLI (modern terminal essentials)
# =============================================================================
brew "git"
brew "zsh"
brew "curl"
brew "wget"
brew "jq"
brew "bat"
brew "eza"
brew "ripgrep"
brew "fd"
brew "fzf"
brew "gum"
brew "zoxide"
brew "starship"
brew "stow"
brew "tealdeer"
brew "micro"
brew "lazygit"
brew "gh"
brew "fnm"
brew "bun"
brew "rtk"
brew "rbw"
brew "uv"
brew "gitleaks"
brew "shfmt"
brew "zsh-syntax-highlighting"
brew "pinentry-mac"

# =============================================================================
# Dev / Languages / Toolchains
# =============================================================================
brew "actionlint"
brew "autoconf"
brew "bash"
brew "cmake"
brew "go"
brew "m4"
brew "openjdk"
brew "pipx"
brew "python-setuptools"
brew "python@3.14"
brew "ruby"
brew "shellcheck"

# =============================================================================
# Containers / Virtualization / Network
# =============================================================================
brew "caddy"
brew "cloudflared"
brew "mtr"
brew "socat"
brew "unbound"

# =============================================================================
# System / Utilities (macOS)
# =============================================================================
brew "bitwarden-cli"
brew "blueutil"
brew "ente-cli"
brew "fastfetch"
brew "htop"
brew "lnav"
brew "ncdu"
brew "ripgrep-all"
brew "switchaudio-osx"
brew "syncthing"

# =============================================================================
# Media / Imaging / Local ML
# =============================================================================
brew "imagemagick"

# =============================================================================
# ZSH plugins
# =============================================================================
tap "Giammarco-Ferranti/deja"
brew "Giammarco-Ferranti/deja/deja"

# =============================================================================
# Tap-scoped formulae
# =============================================================================
brew "muhammadhananasghar/tap/wormhole"
brew "yoanbernabeu/tap/grepai"

# =============================================================================
# Casks — Apps
# =============================================================================
cask "dropbox"
cask "elgato-stream-deck"
cask "ghostty"
cask "localsend"
cask "microsoft-teams"
cask "moonlight"
cask "nvidia-geforce-now"
cask "readdle-spark"
cask "royal-tsx"
cask "setapp"
cask "slack"
cask "spotify"
cask "steam"
cask "the-unarchiver"
cask "zoom"

# =============================================================================
# Casks — Fonts
# =============================================================================
cask "font-hack-nerd-font"
cask "font-jetbrains-mono-nerd-font"
cask "font-juliamono"
cask "font-meslo-lg-nerd-font"
cask "font-poppins"
cask "font-symbols-only-nerd-font"
