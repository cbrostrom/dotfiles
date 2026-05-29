-- WezTerm entry point
-- Cross-platform config (Windows + macOS)
-- Module dirs: ~/.config/wezterm/config/

local wezterm = require('wezterm')
local config = wezterm.config_builder()

config.automatically_reload_config = true
config.check_for_updates = false

require('config.appearance').apply(config)
require('config.platform').apply(config)
require('config.tabs').apply(config)
require('config.keys').apply(config)
require('config.workspaces').apply(config)

return config
