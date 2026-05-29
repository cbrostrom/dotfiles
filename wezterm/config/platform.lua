local wezterm = require('wezterm')
local M = {}

local function is_windows()
  return wezterm.target_triple:find('windows') ~= nil
end

local function is_macos()
  return wezterm.target_triple:find('darwin') ~= nil
end

function M.apply(config)
  if is_windows() then
    -- Auto-discover installed WSL distros (registers them as domains).
    -- Each becomes selectable as 'WSL:<DistroName>' in the launcher.
    config.wsl_domains = wezterm.default_wsl_domains()

    -- Default new tabs/windows/the + button to Debian WSL.
    -- default_prog wins over default_domain when the mux is active, so point
    -- it explicitly at WSL. PowerShell still reachable via launch menu (Leader+s).
    config.default_domain = 'WSL:Debian'
    config.default_prog = { 'wsl.exe', '--distribution', 'Debian', '--cd', '~' }

    config.launch_menu = {
      { label = 'PowerShell',           args = { 'powershell.exe', '-NoLogo' } },
      { label = 'PowerShell 7 (pwsh)',  args = { 'pwsh.exe', '-NoLogo' } },
      { label = 'Command Prompt',       args = { 'cmd.exe' } },
      {
        label = 'Git Bash',
        args = { 'C:\\Program Files\\Git\\bin\\bash.exe', '-i', '-l' },
      },
    }

    config.front_end = 'WebGpu'
    config.webgpu_power_preference = 'HighPerformance'
    -- prefer_egl is a Linux/X11 hint; harmless on Windows but unused.
    config.max_fps = 120
    config.animation_fps = 1
  end

  if is_macos() then
    -- Login shell on mac (homebrew fish; falls back to zsh if missing)
    local fish = '/opt/homebrew/bin/fish'
    if not wezterm.run_child_process({ 'test', '-x', fish }) then
      config.default_prog = { '/bin/zsh', '-l' }
    else
      config.default_prog = { fish, '-l' }
    end

    -- Right Alt for macOS special chars (€, @ etc), left Alt as Meta
    config.send_composed_key_when_left_alt_is_pressed = false
    config.send_composed_key_when_right_alt_is_pressed = true

    config.front_end = 'WebGpu'
    config.max_fps = 120
    config.native_macos_fullscreen_mode = true
  end
end

return M
