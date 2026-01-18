# Gaming Scripts - Quick Start

## ✅ Installation Complete!

Your gaming launcher is now fully integrated into your dotfiles!

## 📁 File Locations

- **Script**: `~/.config/dotfiles/gaming/bin/gamelaunch`
- **Config**: `~/.config/dotfiles/gaming/config/presets.conf`
- **Docs**: `~/.config/dotfiles/gaming/README.md`

## 🔗 Symlinks

- `~/bin/gamelaunch` → script
- `~/.config/game-launcher/presets.conf` → config
- `~/.config/game-launcher/README.md` → docs

## 🎮 Usage in Steam

Right-click game → Properties → Launch Options:

### Recommended (with preset):
```
gamelaunch --preset diablo4 %command%
```

### Manual options:
```
gamelaunch --gamemode --mangohud %command%
```

## 🎯 Available Presets

### Basic Presets
- `default` - Standard gaming with monitoring
- `performance` - Maximum performance, minimal overlay
- `minimal` - Only gamemode, no overlay
- `monitor` - Only MangoHud, no gamemode

### Game-Specific Presets
- `diablo4` - Diablo 4 optimized for NVIDIA (NVAPI + async shaders)
- `diablo4-amd` - Diablo 4 optimized for AMD GPUs
- `poe2` - Path of Exile 2 with DirectX 12 optimization
- `division2` - The Division 2 with EAC and DX11 forced
- `lastepoch` - Last Epoch with VRAM optimization
- `lastepoch-lowvram` - Last Epoch for 4-6GB VRAM cards (OpenGL)

### Generic Presets
- `competitive` - Minimal distractions, stable multiplayer
- `capped60` / `capped120` - FPS limiting
- `debug` - Full monitoring for troubleshooting
- `streaming` - Optimized for OBS

### Hardware-Specific
- `amd-optimized` - Best for AMD GPUs (DXVK_ASYNC + ACO compiler)
- `nvidia-optimized` - Best for NVIDIA GPUs (NVAPI enabled)
- `laptop-dgpu` - Force dedicated GPU on hybrid systems

### Compatibility
- `compatibility` - Use OpenGL instead of Vulkan
- `32bit-fix` - Larger address space for 32-bit games

## 📚 Documentation Files

- **QUICKSTART.md** - Quick reference guide
- **README.md** - Full documentation
- **GAMES.md** - Game-specific configuration guide (Diablo 4, PoE 2, Division 2, Last Epoch)
- **dxvk-configs/** - DXVK configuration templates for specific games

## ⚙️ Customize

Edit presets:
```bash
nano ~/.config/dotfiles/gaming/config/presets.conf
```

After editing, changes are immediately available (no reload needed).

## 🚀 Install on New Machine

Your `install.sh` now automatically sets up gaming scripts:

```bash
cd ~/.config/dotfiles
./install.sh
```

The `setup_gaming()` function:
- Creates necessary directories
- Sets up all symlinks
- Makes scripts executable
- Warns if gamemode/mangohud are missing

## 📊 View Logs

```bash
tail -f ~/.config/game-launcher/launch.log
```

## 🔍 Test

```bash
gamelaunch --preset default echo "Test!"
gamelaunch --help
```

## 📝 Note

After a fresh shell or reboot, `~/bin` should be in your PATH automatically.
If not, you can always use the full path: `~/bin/gamelaunch`

---

For full documentation, see: `~/.config/dotfiles/gaming/README.md`
