# Paru Configuration

Configuration for [paru](https://github.com/Morganamilo/paru) - AUR helper for Arch Linux.

## Location

- **Source:** `~/.config/dotfiles/linux/paru/paru.conf`
- **Symlink:** `~/.config/paru/paru.conf`

## Options

| Option | Description |
|--------|-------------|
| `SkipReview` | Skip PKGBUILD/install file review prompts (no diff shown) |
| `BottomUp` | Show AUR packages first in search results |
| `SudoLoop` | Keep sudo alive during long package builds |
| `CleanAfter` | Automatically clean build files after installation |

## Installation

The config is automatically symlinked when running:

```bash
cd ~/.config/dotfiles/linux
./install-linux.sh
```

Or manually:

```bash
mkdir -p ~/.config/paru
ln -sf ~/.config/dotfiles/linux/paru/paru.conf ~/.config/paru/paru.conf
```

## Usage

After configuration, paru will:
- ✅ Skip asking to review PKGBUILD diffs
- ✅ Show AUR packages first
- ✅ Keep sudo active during builds
- ✅ Clean up build files automatically

## Manual Override

To temporarily review a package:

```bash
paru -S --review package-name
```

To temporarily skip review (if config is not set):

```bash
paru -S --skipreview package-name
```

## Documentation

- [Paru GitHub](https://github.com/Morganamilo/paru)
- [Paru Wiki](https://github.com/Morganamilo/paru/wiki)
