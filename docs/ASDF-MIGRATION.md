# ASDF Migration Guide

## 🚀 **Complete Migration to asdf**

Your dotfiles have been completely rewritten to use **asdf** as the primary version manager, replacing NVM and providing a unified interface for all development tools.

## 📋 **What Changed**

### **Before (v0.x)**

- **NVM** for Node.js management
- **Manual installation** of Go, Rust, Python
- **Separate direnv** installation
- **Multiple version managers** for different tools

### **After (v1.0)**

- **asdf** for all version management
- **asdf-direnv** for environment switching
- **Unified tool management** across all languages
- **Single source of truth** for tool versions

## 🛠️ **asdf Integration**

### **Installed Plugins**

The following plugins are automatically installed and configured:

- **nodejs** - Node.js versions
- **python** - Python versions
- **golang** - Go versions
- **rust** - Rust versions
- **direnv** - Environment switching

### **asdf-direnv Integration**

- **Automatic environment switching** based on `.tool-versions` files
- **Project-specific tool versions** without manual switching
- **Seamless integration** with asdf-managed tools

## 🔧 **New Commands & Aliases**

### **asdf Commands**

```bash
# List all installed tools
asdfls

# Install a specific version
asdfinstall nodejs 20.11.0

# Set global version
asdfglobal nodejs latest:lts

# Set local version (project-specific)
asdflocal nodejs 18.19.0

# Check current versions
asdfcurrent
```

### **Quick Version Switching**

```bash
# Node.js
node16          # asdf local nodejs 16
node18          # asdf local nodejs 18
node20          # asdf local nodejs 20
nodelts         # asdf local nodejs latest:lts

# Python
python3.9       # asdf local python 3.9
python3.11      # asdf local python 3.11
pythonlatest    # asdf local python latest

# Go
go1.20          # asdf local golang 1.20
go1.22          # asdf local golang 1.22
golatest        # asdf local golang latest

# Rust
ruststable      # asdf local rust stable
rustnightly     # asdf local rust nightly
```

## 📁 **Project Configuration**

### **`.tool-versions` File**

Create a `.tool-versions` file in your project root:

```bash
# Example .tool-versions file
nodejs 20.11.0
python 3.11.7
golang 1.22.0
rust 1.75.0
```

### **Automatic Switching**

With asdf-direnv, when you enter a directory with a `.tool-versions` file:

- **Tool versions automatically switch** to match the file
- **Environment variables update** accordingly
- **No manual version management** needed

## 🔄 **Migration Steps**

### **For Existing Projects**

1. **Remove NVM configuration**:

   ```bash
   # Remove .nvmrc files (optional)
   rm .nvmrc
   ```

2. **Create .tool-versions files**:

   ```bash
   # Convert from .nvmrc
   echo "nodejs $(cat .nvmrc)" > .tool-versions

   # Or create manually
   echo "nodejs 20.11.0" > .tool-versions
   ```

3. **Install required versions**:
   ```bash
   # Install all versions listed in .tool-versions
   asdf install
   ```

### **For New Projects**

1. **Initialize project**:

   ```bash
   # Set local versions
   asdf local nodejs latest:lts
   asdf local python 3.11
   ```

2. **Create .tool-versions** (automatic):
   ```bash
   # File is created automatically when using asdf local
   cat .tool-versions
   ```

## 🎯 **Benefits of asdf**

### **Unified Management**

- **Single tool** for all version management
- **Consistent interface** across all languages
- **Simplified workflow** for developers

### **Project Isolation**

- **Automatic version switching** per project
- **No global version conflicts**
- **Reproducible environments**

### **Better Integration**

- **asdf-direnv** for automatic environment switching
- **Shell integration** with completions
- **Plugin ecosystem** for new tools

## 🔧 **Configuration Files**

### **Shell Integration**

asdf is automatically configured in your `.zshrc`:

```bash
# Load asdf
. "$HOME/.asdf/asdf.sh"
. "$HOME/.asdf/completions/asdf.bash"

# Load asdf-direnv integration
eval "$(asdf exec direnv hook zsh)"
```

### **Plugin Management**

Plugins are automatically installed during setup using standard asdf plugin names:

- **nodejs** - Node.js versions
- **python** - Python versions
- **golang** - Go versions
- **rust** - Rust versions
- **direnv** - Environment switching

These plugins are installed using `asdf plugin add <name>` and are sourced from the official asdf plugin repository.

## 🚨 **Breaking Changes**

### **Removed**

- **NVM** - Replaced by asdf nodejs plugin
- **Manual Go installation** - Now via asdf golang plugin
- **Manual Rust installation** - Now via asdf rust plugin
- **Standalone direnv** - Now via asdf-direnv plugin

### **Updated Commands**

- `nvm use` → `asdf local nodejs <version>`
- `nvm install` → `asdf install nodejs <version>`
- `go install` → `asdf install golang <version>`
- `rustup` → `asdf install rust <version>`

## 📚 **Useful Commands**

### **asdf Management**

```bash
# List all plugins
asdf plugin list

# List all versions for a tool
asdf list all nodejs

# Install latest LTS
asdf install nodejs latest:lts

# Set global default
asdf global nodejs latest:lts

# Remove a version
asdf uninstall nodejs 18.19.0
```

### **Project Management**

```bash
# Set project-specific versions
asdf local nodejs 20.11.0
asdf local python 3.11.7

# Install all project versions
asdf install

# Check what versions are active
asdf current
```

## 🎉 **Migration Complete**

Your dotfiles now use **asdf** as the primary version manager with:

- ✅ **Unified tool management**
- ✅ **asdf-direnv integration**
- ✅ **Project-specific environments**
- ✅ **Automatic version switching**
- ✅ **Simplified workflow**

**Enjoy the improved development experience!** 🚀
