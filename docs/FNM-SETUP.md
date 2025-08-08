# fnm (Fast Node Manager) Setup

## Overview

Your dotfiles now use **fnm** (Fast Node Manager) for Node.js version management instead of asdf. This provides better `.nvmrc` support and faster performance.

## Why fnm over asdf for Node.js?

- **Better `.nvmrc` support**: Automatically switches Node.js versions when you enter directories with `.nvmrc` files
- **Faster performance**: Written in Rust, significantly faster than nvm
- **Cross-platform**: Works on macOS, Linux, and Windows
- **Simple installation**: Easy to install via Homebrew or curl
- **Compatible**: Works with existing `.nvmrc` files without modification

## Installation

fnm is automatically installed during the dotfiles installation process:

```bash
./install.sh
```

Or install manually:

```bash
# macOS
brew install fnm

# Linux
curl -fsSL https://fnm.vercel.app/install | bash
```

## Configuration

The dotfiles automatically configure fnm in your shell:

```bash
# Added to ~/.zshrc
eval "$(fnm env --use-on-cd)"
alias nvm="fnm"  # Alias for compatibility
```

This enables automatic version switching based on `.nvmrc` files and provides `nvm` as an alias for `fnm` for better compatibility.

## Usage

### Basic Commands

```bash
# Install latest LTS
fnm install --lts

# Install specific version
fnm install 18.17.0

# Use specific version
fnm use 18.17.0

# Set default version
fnm default 18.17.0

# List installed versions
fnm list

# List available versions
fnm list-remote
```

### .nvmrc Support

Create a `.nvmrc` file in your project:

```bash
echo "18.17.0" > .nvmrc
```

When you enter the directory, fnm automatically switches to the specified version:

```bash
cd my-project  # Automatically switches to Node.js 18.17.0
node --version # v18.17.0
```

### Migration from asdf

If you're migrating from asdf, use the migration script:

```bash
./migrate-to-fnm.sh
```

This will:

1. Backup your current Node.js setup
2. Install fnm
3. Migrate Node.js versions
4. Update shell configuration
5. Remove asdf Node.js plugin
6. Test the setup

### nvm Compatibility

For users familiar with nvm, the dotfiles provide an alias:

```bash
# Both commands work the same way
fnm install --lts
nvm install --lts

fnm use 18.17.0
nvm use 18.17.0

fnm list
nvm list
```

This makes the transition from nvm to fnm seamless.

## Benefits

### Automatic Version Switching

```bash
# Project A uses Node.js 16
cd project-a
node --version  # v16.20.0

# Project B uses Node.js 18
cd ../project-b
node --version  # v18.17.0
```

### Fast Installation

```bash
# Install Node.js versions quickly
fnm install 16.20.0  # Much faster than nvm
fnm install 18.17.0
fnm install 20.5.0
```

### Global Default

```bash
# Set a global default
fnm default 18.17.0

# This version will be used when no .nvmrc is present
node --version  # v18.17.0
```

## Troubleshooting

### fnm not found

```bash
# Restart your terminal or reload shell config
source ~/.zshrc
```

### .nvmrc not working

```bash
# Check if fnm is properly configured
fnm env --use-on-cd

# Verify .nvmrc file format
cat .nvmrc  # Should contain just the version number
```

### Version not available

```bash
# List available versions
fnm list-remote

# Install specific version
fnm install 18.17.0
```

## Comparison with Other Tools

| Feature        | fnm        | nvm        | asdf       |
| -------------- | ---------- | ---------- | ---------- |
| Speed          | ⭐⭐⭐⭐⭐ | ⭐⭐       | ⭐⭐⭐     |
| .nvmrc support | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐       |
| Cross-platform | ⭐⭐⭐⭐⭐ | ⭐⭐⭐     | ⭐⭐⭐⭐⭐ |
| Installation   | ⭐⭐⭐⭐⭐ | ⭐⭐⭐     | ⭐⭐⭐     |
| Memory usage   | ⭐⭐⭐⭐⭐ | ⭐⭐       | ⭐⭐⭐     |

## Integration with Other Tools

### direnv

fnm works well with direnv for project-specific environment variables:

```bash
# .envrc
use nodejs 18.17.0
```

### Starship Prompt

The starship prompt automatically detects Node.js versions managed by fnm.

### IDE Integration

Most IDEs (VS Code, IntelliJ, etc.) work seamlessly with fnm-managed Node.js versions.

## Commands Reference

```bash
fnm install <version>     # Install specific version
fnm install --lts         # Install latest LTS
fnm use <version>         # Use specific version
fnm default <version>     # Set default version
fnm list                  # List installed versions
fnm list-remote          # List available versions
fnm current              # Show current version
fnm env                  # Show environment setup
fnm env --use-on-cd     # Setup for auto-switching
fnm uninstall <version>  # Remove specific version
fnm alias <name> <version> # Create alias
fnm completions --shell zsh # Generate completions
```

**Note**: All `fnm` commands can also be used with `nvm` (aliased):
```bash
nvm install <version>     # Same as fnm install <version>
nvm use <version>         # Same as fnm use <version>
nvm list                  # Same as fnm list
# ... and so on
```

## File Locations

- **Installation**: `~/.local/share/fnm/`
- **Config**: `~/.config/fnm/`
- **Shell integration**: `~/.zshrc`

## Support

For issues with fnm itself, see the [fnm GitHub repository](https://github.com/Schniz/fnm).

For dotfiles-specific issues, check the main documentation or run:

```bash
./status.sh  # Check installation status
```
