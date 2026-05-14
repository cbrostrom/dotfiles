# Brewfile — macOS only (mac / Macbook = AKQABro)
# Source of truth for `brew bundle install` AND `brew bundle cleanup`.
# WARNING: anything NOT listed here will be removed by `brew bundle cleanup --force`.
#
# Trim policy:
#   - Removed 13 unused taps (no formula referenced).
#   - Removed entire "library deps" section: those are transitive deps
#     of imagemagick / llama.cpp / qemu / docker / etc. brew bundle cleanup
#     does NOT remove formulae that are deps of installed parents, so
#     explicit pinning was unnecessary noise.
#   - Removed zellij (already dropped per commit bb316c4).
#   - Removed casks dbgate, dotnet-sdk, syncthing-app, voicemod
#     (not installed on current host; re-add if needed elsewhere).
#
# FIXME comments mark personal-choice duplicates (e.g. 3 prompts, 2 node
# version managers, 3 python versions). Pick one and drop the rest.

# =============================================================================
# Taps
# =============================================================================
tap "felixkratz/formulae"            # borders
tap "gentleman-programming/tap"      # engram
tap "muhammadhananasghar/tap"        # wormhole
tap "tomanthony/brews"               # itermocil
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
brew "tealdeer"
brew "micro"
brew "lazygit"
brew "gh"
brew "fnm"
brew "bun"
brew "pinentry-mac"

# =============================================================================
# Dev / Languages / Toolchains
# =============================================================================
brew "actionlint"
brew "autoconf"
brew "bash"
brew "cmake"
brew "dotnet@6"
brew "go"
brew "m4"
brew "node"                           # kept: some tools need a global node
brew "openjdk"
brew "pipx"
brew "python-setuptools"
brew "python@3.14"
brew "ruby"
brew "shellcheck"
brew "vercel-cli"

# =============================================================================
# Containers / Virtualization / Network
# =============================================================================
brew "caddy"
brew "cloudflared"
brew "docker"
brew "docker-buildx"
brew "docker-completion"
brew "docker-compose"
brew "docker-credential-helper"
brew "mtr"
brew "podman"
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
brew "lsd"
brew "ncdu"
brew "ranger"
brew "ripgrep-all"
brew "switchaudio-osx"
brew "syncthing"

# =============================================================================
# Media / Imaging / Local ML
# =============================================================================
brew "ggml"
brew "imagemagick"
brew "llama.cpp"

# =============================================================================
# ZSH plugins
# =============================================================================
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"

# =============================================================================
# Tap-scoped formulae
# =============================================================================
brew "felixkratz/formulae/borders"
brew "gentleman-programming/tap/engram"
brew "muhammadhananasghar/tap/wormhole"
brew "tomanthony/brews/itermocil"
brew "yoanbernabeu/tap/grepai"

# =============================================================================
# Casks — Apps
# =============================================================================
cask "barrier"
cask "beeper"
cask "bitwarden"
cask "claude"
cask "codeisland"
cask "cursor"
cask "vscodium"
cask "dropbox"
cask "elgato-stream-deck"
cask "figma"
cask "gcloud-cli"
cask "ghostty"
cask "localsend"
cask "logi-options+"
cask "microsoft-teams"
cask "miro"
cask "moonlight"
cask "music-decoy"
cask "nvidia-geforce-now"
cask "pearcleaner"
cask "pronotes"
cask "readdle-spark"
cask "royal-tsx"
cask "setapp"
cask "slack"
cask "spotify"
cask "steam"
cask "the-unarchiver"
cask "vivaldi"
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
