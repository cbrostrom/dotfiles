local wezterm = require('wezterm')
local M = {}

-- Persistent multiplexer:
-- - On Windows + macOS we run a Unix domain mux server.
-- - GUI client connects to it; when GUI closes, panes/tabs survive.
-- - Reconnect on next launch with the same workspace state.
--
-- Connect manually if needed:
--   wezterm connect main
--
-- List sessions: wezterm cli list

function M.apply(config)
  config.unix_domains = {
    { name = 'main' },
  }

  -- Auto-connect to the 'main' mux on startup so workspaces persist
  -- across GUI restarts. Comment out if you want a fresh window each time.
  config.default_gui_startup_args = { 'connect', 'main' }

  -- Default workspace shown in status bar
  config.default_workspace = 'main'

  -- Quality-of-life: when starting a new tab, inherit the cwd of current pane
  config.default_cwd = wezterm.home_dir

  -- Workspace launcher gets fuzzy matching by default (set in keys.lua)
end

return M
