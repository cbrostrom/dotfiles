# Modular ZSH Configuration

This directory contains modular zsh configuration files for better organization and maintainability.

## Structure

```
zsh/
├── 01-environment.zsh  - OS detection, PATH, environment variables
├── 02-plugins.zsh      - zinit, FZF, completions, zoxide, starship, fnm
├── 03-aliases.zsh      - Modern tool replacements and shortcuts
├── 04-functions.zsh    - Custom functions and utilities
└── 05-integrations.zsh - Editor integrations (Cursor, VS Code)
```

## Loading Order

Modules are loaded in numerical order by the main `.zshrc` file:

1. **01-environment.zsh** - Sets up OS detection, terminal configuration, PATH, and environment variables
2. **02-plugins.zsh** - Loads zinit plugins, sets up FZF, completions, zoxide, starship, and fnm
3. **03-aliases.zsh** - Defines aliases for modern CLI tools
4. **04-functions.zsh** - Custom shell functions
5. **05-integrations.zsh** - Editor and platform integrations

## Features

### Performance Optimizations

- **Lazy Loading**: Critical plugins (autosuggestions, syntax highlighting) load immediately, others lazy load
- **Completion Caching**: Only checks completions once per day for faster shell startup
- **FZF Consolidation**: All FZF configuration in one place

### Module Benefits

- **Easy to Edit**: Each module focuses on one aspect
- **Easy to Debug**: Isolate issues to specific modules
- **Easy to Customize**: Add/remove entire modules
- **Cross-Platform**: OS-specific logic contained in environment module

## Customization

### Adding a New Module

1. Create a new file: `0X-modulename.zsh`
2. Add your configuration
3. Add a source line in `.zshrc`:

```zsh
[[ -f "$ZSH_MODULES_DIR/0X-modulename.zsh" ]] && source "$ZSH_MODULES_DIR/0X-modulename.zsh"
```

### Machine-Specific Configuration

Create `~/.zshrc.local` for machine-specific configuration that won't be tracked in git:

```zsh
# ~/.zshrc.local
export MY_LOCAL_VAR="value"
alias local_alias='command'
```

## Troubleshooting

### Module Not Loading

Check if the module file exists:

```bash
ls -la ~/dotfiles/zsh/
```

### Shell Startup Slow

Enable profiling:

1. Add to top of `.zshrc`: `zmodload zsh/zprof`
2. Add to bottom: `zprof`
3. Restart shell to see timing report

### Syntax Errors

Test a specific module:

```bash
zsh -n ~/dotfiles/zsh/0X-modulename.zsh
```

## Migration from Old .zshrc

The old `.zshrc` has been backed up to:
- `/Users/Christian.Brostrom/dotfiles/.zshrc.backup`

If you need to restore:

```bash
cp ~/dotfiles/.zshrc.backup ~/.zshrc
source ~/.zshrc
```

## See Also

- Main README: `../README.md`
- Backup script: `../backup.sh`
- Installation script: `../install.sh`

