# macOS-Specific Configurations

This directory contains macOS-specific configurations and tools.

## 📁 Structure

```
macos/
├── ghostty/              # Ghostty terminal emulator
│   ├── config
│   └── colorschemes/
│
└── windows-terminal/     # Windows Terminal (for reference)
    └── settings.json
```

## 🚀 Usage

### Ghostty Terminal

Ghostty configurations are automatically symlinked during installation on macOS.

```bash
# Manual symlink
ln -sf ~/dotfiles/macos/ghostty ~/.config/ghostty
```

## 🔧 Future macOS Tools

Additional macOS-specific tools can be added here:
- Aerospace (window manager)
- Yabai (tiling)
- Raycast configurations
- macOS-specific aliases/scripts
