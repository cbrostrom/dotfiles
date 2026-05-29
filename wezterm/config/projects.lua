-- Project workspace launcher.
-- Scans ~/Projects/* and presents a fuzzy picker. Selecting a project
-- creates (or switches to) a workspace named after the directory, with
-- the cwd set to the project path.
--
-- Adapted from https://alexplescan.com/posts/2024/08/10/wezterm/

local wezterm = require('wezterm')
local M = {}

-- Project root directory. Override with WEZTERM_PROJECT_DIR env var.
local function project_root()
  local override = os.getenv('WEZTERM_PROJECT_DIR')
  if override and override ~= '' then return override end
  return wezterm.home_dir .. '/Projects'
end

local function path_sep()
  return wezterm.target_triple:find('windows') and '\\' or '/'
end

local function project_dirs()
  local projects = { wezterm.home_dir }
  local root = project_root()
  local sep = path_sep()

  -- wezterm.glob handles forward-slashes on Windows too
  local ok, dirs = pcall(wezterm.glob, root .. '/*')
  if not ok or not dirs then return projects end

  for _, dir in ipairs(dirs) do
    table.insert(projects, dir)
  end
  return projects
end

local function basename(path)
  -- Last segment after / or \
  return path:match('([^/\\]+)[/\\]?$') or path
end

function M.choose_project()
  local choices = {}
  for _, dir in ipairs(project_dirs()) do
    table.insert(choices, { label = dir })
  end

  return wezterm.action.InputSelector({
    title = 'Switch to project workspace',
    choices = choices,
    fuzzy = true,
    action = wezterm.action_callback(function(window, pane, id, label)
      if not label or label == '' then return end
      window:perform_action(
        wezterm.action.SwitchToWorkspace({
          name = basename(label),
          spawn = { cwd = label },
        }),
        pane
      )
    end),
  })
end

return M
