local wezterm = require('wezterm')
local act = wezterm.action
local projects = require('config.projects')
local M = {}

function M.apply(config)
  -- Leader: Ctrl+a (tmux-style), 1.5s window
  config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1500 }

  config.disable_default_key_bindings = false

  config.keys = {
    -- Send literal Ctrl+a
    { key = 'a', mods = 'LEADER|CTRL', action = act.SendKey { key = 'a', mods = 'CTRL' } },

    -- Splits
    { key = '|', mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = '\\',mods = 'LEADER',       action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = '-', mods = 'LEADER',       action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },

    -- Pane navigation (vim-style)
    { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
    { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
    { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
    { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },

    -- Enter resize mode (key table). Inside: h/j/k/l adjust size,
    -- mode auto-exits after 1.5s of no input. Esc/q exits early.
    { key = 'R', mods = 'LEADER|SHIFT', action = act.ActivateKeyTable {
        name = 'resize_panes',
        one_shot = false,
        timeout_milliseconds = 1500,
    } },

    -- Pane management
    { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },
    { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
    { key = 'o', mods = 'LEADER', action = act.RotatePanes 'Clockwise' },

    -- Tabs
    { key = 't', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
    { key = 'c', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
    { key = 'n', mods = 'LEADER', action = act.ActivateTabRelative(1) },
    { key = 'p', mods = 'LEADER', action = act.ActivateTabRelative(-1) },
    { key = '&', mods = 'LEADER|SHIFT', action = act.CloseCurrentTab { confirm = true } },

    -- Tab number jumps
    { key = '1', mods = 'LEADER', action = act.ActivateTab(0) },
    { key = '2', mods = 'LEADER', action = act.ActivateTab(1) },
    { key = '3', mods = 'LEADER', action = act.ActivateTab(2) },
    { key = '4', mods = 'LEADER', action = act.ActivateTab(3) },
    { key = '5', mods = 'LEADER', action = act.ActivateTab(4) },
    { key = '6', mods = 'LEADER', action = act.ActivateTab(5) },
    { key = '7', mods = 'LEADER', action = act.ActivateTab(6) },
    { key = '8', mods = 'LEADER', action = act.ActivateTab(7) },
    { key = '9', mods = 'LEADER', action = act.ActivateTab(8) },

    -- Workspaces
    { key = 's', mods = 'LEADER',
      action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' } },
    -- Project workspace launcher (fuzzy pick from ~/Projects/*)
    { key = 'f', mods = 'LEADER', action = projects.choose_project() },
    { key = 'w', mods = 'LEADER',
      action = act.PromptInputLine {
        description = 'Create / switch to workspace',
        action = wezterm.action_callback(function(window, pane, line)
          if line and line ~= '' then
            window:perform_action(act.SwitchToWorkspace { name = line }, pane)
          end
        end),
      } },
    { key = '[', mods = 'LEADER', action = act.SwitchWorkspaceRelative(-1) },
    { key = ']', mods = 'LEADER', action = act.SwitchWorkspaceRelative(1) },

    -- Copy mode + search
    { key = '/', mods = 'LEADER', action = act.Search 'CurrentSelectionOrEmptyString' },
    { key = '[', mods = 'CTRL|SHIFT', action = act.ActivateCopyMode },
    { key = 'v', mods = 'LEADER', action = act.ActivateCopyMode },

    -- Misc
    { key = 'r', mods = 'LEADER', action = act.ReloadConfiguration },
    { key = 'P', mods = 'LEADER|SHIFT', action = act.ActivateCommandPalette },
    { key = 'F', mods = 'LEADER|SHIFT', action = act.ToggleFullScreen },
    { key = 'L', mods = 'CTRL',   action = act.ClearScrollback 'ScrollbackAndViewport' },

    -- Quick spawn launcher menu
    { key = 'Space', mods = 'LEADER', action = act.ShowLauncher },

    -- Clipboard — system-standard Ctrl+C / Ctrl+V (Windows convention).
    -- Ctrl+C is smart: copies if there's a selection, otherwise falls through
    -- as a normal SIGINT so shells/REPLs still work as expected.
    { key = 'c', mods = 'CTRL', action = wezterm.action_callback(function(window, pane)
        local sel = window:get_selection_text_for_pane(pane)
        if sel and sel ~= '' then
          window:perform_action(act.CopyTo 'Clipboard', pane)
          window:perform_action(act.ClearSelection, pane)
        else
          window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
        end
      end),
    },
    { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },

    -- Keep the terminal-standard bindings as a backup
    { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
    { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },

    -- Font size
    { key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
    { key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
    { key = '0', mods = 'CTRL', action = act.ResetFontSize },
  }

  -- Helper: build a resize entry
  local function resize(key, dir)
    return { key = key, action = act.AdjustPaneSize { dir, 3 } }
  end

  config.key_tables = {
    resize_panes = {
      resize('h', 'Left'),
      resize('j', 'Down'),
      resize('k', 'Up'),
      resize('l', 'Right'),
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'q',      action = 'PopKeyTable' },
      { key = 'Enter',  action = 'PopKeyTable' },
    },

    copy_mode = {
      { key = 'Escape', action = act.CopyMode 'Close' },
      { key = 'q',      action = act.CopyMode 'Close' },
      { key = 'h',      action = act.CopyMode 'MoveLeft' },
      { key = 'j',      action = act.CopyMode 'MoveDown' },
      { key = 'k',      action = act.CopyMode 'MoveUp' },
      { key = 'l',      action = act.CopyMode 'MoveRight' },
      { key = 'w',      action = act.CopyMode 'MoveForwardWord' },
      { key = 'b',      action = act.CopyMode 'MoveBackwardWord' },
      { key = '0',      action = act.CopyMode 'MoveToStartOfLine' },
      { key = '$',      action = act.CopyMode 'MoveToEndOfLineContent' },
      { key = 'g',      action = act.CopyMode 'MoveToScrollbackTop' },
      { key = 'G',      action = act.CopyMode 'MoveToScrollbackBottom' },
      { key = 'v',      action = act.CopyMode { SetSelectionMode = 'Cell' } },
      { key = 'V',      action = act.CopyMode { SetSelectionMode = 'Line' } },
      { key = 'y',      action = act.Multiple {
        { CopyTo = 'ClipboardAndPrimarySelection' },
        { CopyMode = 'Close' },
      } },
      { key = '/',      action = act.Search 'CurrentSelectionOrEmptyString' },
    },

    search_mode = {
      { key = 'Escape', action = act.CopyMode 'Close' },
      { key = 'Enter',  action = act.CopyMode 'PriorMatch' },
      { key = 'n',      mods = 'CTRL', action = act.CopyMode 'NextMatch' },
      { key = 'p',      mods = 'CTRL', action = act.CopyMode 'PriorMatch' },
    },
  }

  -- Mouse: right-click pastes (Windows convention friendly)
  config.mouse_bindings = {
    {
      event = { Down = { streak = 1, button = 'Right' } },
      mods = 'NONE',
      action = act.PasteFrom 'Clipboard',
    },
    {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'NONE',
      action = act.CompleteSelection 'ClipboardAndPrimarySelection',
    },
    {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'CTRL',
      action = act.OpenLinkAtMouseCursor,
    },
  }
end

return M
