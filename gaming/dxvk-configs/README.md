# Game-Specific DXVK Configurations

This directory contains DXVK configuration templates for specific games that need custom VRAM or memory management settings.

## How to Use

### Method 1: Manual Copy
Copy the appropriate config file to your game directory:

```bash
# Example for Diablo 4 (NVIDIA)
cp ~/.config/dotfiles/gaming/dxvk-configs/diablo4-nvidia.conf \
   ~/.local/share/Steam/steamapps/common/"Diablo IV"/dxvk.conf
```

### Method 2: Symlink (Automatic Updates)
Create a symlink so updates to the template automatically apply:

```bash
# Example for Diablo 4 (NVIDIA)
ln -sf ~/.config/dotfiles/gaming/dxvk-configs/diablo4-nvidia.conf \
       ~/.local/share/Steam/steamapps/common/"Diablo IV"/dxvk.conf
```

## Available Configs

- `diablo4-nvidia.conf` - Diablo 4 optimized for NVIDIA GPUs (fixes VRAM leaks)
- `diablo4-amd.conf` - Diablo 4 optimized for AMD GPUs
- `lastepoch.conf` - Last Epoch VRAM optimization

## Adjusting for Your GPU

Each config file contains commented values for different VRAM sizes. Edit the file and uncomment/adjust the values based on your GPU:

```conf
# For a 12GB card:
dxgi.maxDeviceMemory = 10240  # Leave ~2GB headroom
dxgi.maxSharedMemory = 2048   # System RAM to use
```

## Finding Your Game Directory

Steam games are typically located at:
```
~/.local/share/Steam/steamapps/common/[GAME NAME]/
```

To find a specific game:
```bash
find ~/.local/share/Steam/steamapps/common/ -name "*.exe" | grep -i "diablo"
```

## Verifying Configuration

Check if your config is being used by looking for DXVK logs or using:
```bash
DXVK_LOG_LEVEL=info gamelaunch --preset diablo4 %command%
```
