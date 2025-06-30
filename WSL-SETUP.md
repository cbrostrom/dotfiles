# WSL Setup Guide - From Scratch

Complete guide to set up dotfiles on a fresh WSL installation.

## 🚀 **Quick Start (Automated)**

If you want to automate everything:

```bash
# 1. Download and run the setup script
curl -fsSL https://raw.githubusercontent.com/cbrostrom/dotfiles/main/scripts/wsl-setup.sh | bash

# 2. Clone your dotfiles
git clone https://github.com/cbrostrom/dotfiles.git ~/dotfiles

# 3. Install dotfiles
cd ~/dotfiles
./scripts/dotfiles.sh install

# 4. Install tools
./scripts/install-tools.sh

# 5. Restart terminal
exec zsh
```

## 📋 **Manual Setup (Step by Step)**

### **Step 1: System Preparation**

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y \
    git \
    curl \
    wget \
    unzip \
    build-essential \
    python3 \
    python3-pip \
    zsh \
    ca-certificates \
    gnupg \
    lsb-release
```

### **Step 2: Install Development Tools**

```bash
# Install Python tools
pip3 install --user pipx
pipx ensurepath

# Install Rust (for modern CLI tools)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
```

### **Step 3: Configure Shell**

```bash
# Set zsh as default shell
chsh -s /bin/zsh

# Create necessary directories
mkdir -p ~/.local/bin
mkdir -p ~/.config
mkdir -p ~/.cache
```

### **Step 4: Configure Git**

```bash
# Set up git (replace with your details)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Optional: Set default branch name
git config --global init.defaultBranch main
```

### **Step 5: Clone and Install Dotfiles**

```bash
# Clone your dotfiles repository
git clone https://github.com/your-username/dotfiles.git ~/dotfiles

# Navigate to dotfiles
cd ~/dotfiles

# Install dotfiles (creates symlinks)
./scripts/dotfiles.sh install

# Install tools (optional)
./scripts/install-tools.sh
```

### **Step 6: Restart and Verify**

```bash
# Restart your shell
exec zsh

# Test the installation
dotfiles help
dotfiles list
```

## 🔧 **Troubleshooting**

### **If zsh is not found:**

```bash
sudo apt install zsh
chsh -s /bin/zsh
```

### **If git is not configured:**

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### **If dotfiles command doesn't work:**

```bash
# Reload aliases
source ~/.config/zsh/aliases

# Or restart shell
exec zsh
```

### **If tools don't install:**

```bash
# Check what's available
./scripts/diagnose.sh

# Install manually
./scripts/install-tools.sh
```

## 📦 **What Gets Installed**

### **System Packages:**

- ✅ Git, curl, wget, unzip
- ✅ Python3, pip3, pipx
- ✅ Node.js, npm
- ✅ Zsh (default shell)
- ✅ Build tools

### **Development Tools:**

- ✅ Rust (for modern CLI tools)
- ✅ Python tools
- ✅ Node.js tools

### **Dotfiles Tools:**

- ✅ lsd (modern ls)
- ✅ bat (better cat)
- ✅ ripgrep (fast grep)
- ✅ fd (fast find)
- ✅ fzf (fuzzy finder)
- ✅ lazygit (git TUI)
- ✅ tldr (command help)
- ✅ direnv (auto env switching)
- ✅ starship (prompt)

## 🎯 **Verification Checklist**

After setup, verify these work:

- [ ] `zsh` starts without errors
- [ ] `dotfiles help` shows help
- [ ] `dotfiles list` shows status
- [ ] `lsd` works (modern ls)
- [ ] `bat` works (better cat)
- [ ] `fzf` works (fuzzy finder)
- [ ] `starship` prompt shows

## 🚨 **Common Issues**

### **Permission Denied:**

```bash
chmod +x scripts/*.sh
```

### **Path Issues:**

```bash
# Check if PATH includes local bin
echo $PATH | grep -q ~/.local/bin || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

### **Git Issues:**

```bash
# Configure git if not done
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## 🎉 **Success!**

Once everything is working, you'll have:

- ✅ Modern shell with zsh
- ✅ Beautiful prompt with starship
- ✅ Fast fuzzy finding with fzf
- ✅ Modern CLI tools
- ✅ Cross-platform dotfiles management

Your WSL environment is now ready for development! 🚀
