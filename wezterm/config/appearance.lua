local wezterm = require('wezterm')
local M = {}

function M.apply(config)
  config.color_scheme = 'Catppuccin Mocha'

  -- JetBrainsMono NFM = "Nerd Font Mono" variant: monospace cells for icons.
  -- (Older docs call it "JetBrainsMono Nerd Font Mono" but the registered
  -- Windows family name is "JetBrainsMono NFM".)
  config.font = wezterm.font_with_fallback({
    { family = 'JetBrainsMono NFM',       weight = 'Regular' },
    { family = 'JetBrainsMono Nerd Font', weight = 'Regular' },  -- macOS name
    { family = 'JetBrains Mono',          weight = 'Regular' },
    { family = 'Cascadia Code',           weight = 'Regular' },
    'Symbols Nerd Font Mono',
  })
  config.font_size = 11.0
  config.line_height = 1.1
  config.cell_width = 1.0
  config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }

  -- RESIZE|INTEGRATED_BUTTONS = resize border + min/max/close buttons
  -- embedded in the tab bar (right side). No native title bar.
  config.window_decorations = 'RESIZE|INTEGRATED_BUTTONS'
  config.integrated_title_button_style = 'Windows'
  config.window_padding = { left = 10, right = 10, top = 8, bottom = 4 }

  -- Transparency strategy:
  --   Windows 11: opacity ~0.95 (Acrylic backdrop tried, doesn't render on this
  --               machine even with Transparency effects ON — known wezterm/Win11 issue)
  --   macOS:      opacity ~0.85 + native blur
  --   Fallback:   opacity ~0.95
  local target = require('wezterm').target_triple
  if target:find('windows') then
    config.window_background_opacity = 0.95
    config.win32_system_backdrop = 'Auto'
  elseif target:find('darwin') then
    config.window_background_opacity = 0.85
    config.macos_window_background_blur = 25
  else
    config.window_background_opacity = 0.95
  end
  config.initial_cols = 140
  config.initial_rows = 38

  config.enable_scroll_bar = false
  config.scrollback_lines = 50000
  config.audible_bell = 'Disabled'
  config.visual_bell = {
    fade_in_duration_ms = 0,
    fade_out_duration_ms = 0,
  }

  -- Steady cursor — blinking + easing triggers constant repaints, which
  -- on Windows + WebGpu can show up as input-latency jitter.
  config.cursor_blink_rate = 0
  config.default_cursor_style = 'SteadyBar'

  config.inactive_pane_hsb = {
    saturation = 0.85,
    brightness = 0.75,
  }
end

return M
