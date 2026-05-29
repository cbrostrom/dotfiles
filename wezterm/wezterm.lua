-- WezTerm entry point
-- Cross-platform config (Windows + macOS)
-- Module dirs: ~/.config/wezterm/config/

local wezterm = require('wezterm')
local config = wezterm.config_builder()

config.automatically_reload_config = true
config.check_for_updates = false

-- AI-agent status plugin (Claude Code, OpenCode, Aider, etc.). Tab/right-status
-- rendering disabled — tabs.lua composes the status dot into our own layout.
-- Wrapped in pcall so an offline first-run doesn't brick the config.
local agent_deck
do
  local ok, plugin = pcall(wezterm.plugin.require, 'https://github.com/Eric162/wezterm-agent-deck')
  if ok then
    plugin.apply_to_config(config, {
      update_interval = 500,
      tab_title    = { enabled = false },
      right_status = { enabled = false },
      notifications = { enabled = true, on_waiting = true },
    })
    agent_deck = plugin
  else
    wezterm.log_warn('agent-deck plugin failed to load: ' .. tostring(plugin))
  end
end

-- Quake-style dropdown pane (Ctrl+; toggles a small terminal in the current tab).
do
  local ok, toggle_terminal = pcall(wezterm.plugin.require,
    'https://github.com/zsh-sage/toggle_terminal.wez')
  if ok then
    -- F12 instead of plugin default Ctrl+; — `;` is Shift+, on Danish keyboard.
    toggle_terminal.apply_to_config(config, {
      key = 'F12',
      mods = '',
      direction = 'Up',
      size = { Percent = 30 },
      zoom = {
        auto_zoom_toggle_terminal = false,
        auto_zoom_invoker_pane    = true,
        remember_zoomed           = true,
      },
    })
  else
    wezterm.log_warn('toggle_terminal plugin failed to load: ' .. tostring(toggle_terminal))
  end
end

-- Chord: Vim-style key notation + modal hints + command picker.
-- Auto-pulls memo.wz and warp.wz as transitive deps.
local chord
do
  local ok, plugin = pcall(wezterm.plugin.require, 'https://github.com/sravioli/chord.wz')
  if ok then
    chord = plugin
  else
    wezterm.log_warn('chord plugin failed to load: ' .. tostring(plugin))
  end
end

require('config.appearance').apply(config)
require('config.platform').apply(config)
require('config.tabs').apply(config, agent_deck)
require('config.keys').apply(config, { chord = chord })
require('config.workspaces').apply(config)

return config
