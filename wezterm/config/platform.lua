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

    -- Pick a sane default shell: prefer pwsh (PS7) if installed, else PS5.
    local function exists(cmd)
      local ok = wezterm.run_child_process({ 'where.exe', cmd })
      return ok
    end

    if exists('pwsh.exe') then
      config.default_prog = { 'pwsh.exe', '-NoLogo' }
    else
      config.default_prog = { 'powershell.exe', '-NoLogo' }
    end

    -- Default new tabs/windows to Debian WSL.
    -- (default_prog above is the fallback for when no domain applies.)
    config.default_domain = 'WSL:Debian'

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
    config.prefer_egl = true
    config.max_fps = 120
    config.animation_fps = 60
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
