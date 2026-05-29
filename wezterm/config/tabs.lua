local wezterm = require('wezterm')
local M = {}

-- Catppuccin Mocha palette (matches color_scheme)
local colors = {
  base     = '#1e1e2e',
  mantle   = '#181825',
  crust    = '#11111b',
  surface0 = '#313244',
  surface1 = '#45475a',
  text     = '#cdd6f4',
  subtext0 = '#a6adc8',
  overlay0 = '#6c7086',
  blue     = '#89b4fa',
  sapphire = '#74c7ec',
  mauve    = '#cba6f7',
  green    = '#a6e3a1',
  peach    = '#fab387',
  yellow   = '#f9e2af',
  red      = '#f38ba8',
  teal     = '#94e2d5',
}

-- Nerd Font glyphs (kept as utf8.char so the file stays ASCII-safe in the editor)
local ICON = {
  TERMINAL   = utf8.char(0xf120),  -- nf-fa-terminal
  POWERSHELL = utf8.char(0xebc7),  -- nf-cod-terminal_powershell
  BASH       = utf8.char(0xebca),  -- nf-cod-terminal_bash
  CMD        = utf8.char(0xf17a),  -- nf-fa-windows
  DEBIAN     = utf8.char(0xf306),  -- nf-linux-debian
  TUX        = utf8.char(0xf17c),  -- nf-linux-tux
  VIM        = utf8.char(0xe7c5),  -- nf-dev-vim
  FISH       = utf8.char(0xf739),  -- nf-md-fish
  NODE       = utf8.char(0xe718),  -- nf-dev-nodejs_small
  PYTHON     = utf8.char(0xe73c),  -- nf-dev-python
  GIT        = utf8.char(0xe702),  -- nf-dev-git
  DOCKER     = utf8.char(0xf308),  -- nf-linux-docker
  SSH        = utf8.char(0xeba9),  -- nf-cod-remote
  CHART      = utf8.char(0xf85a),  -- nf-md-chart_bar (btop/htop)
  CLAUDE     = utf8.char(0xf5da),  -- nf-md-robot
}

-- Map foreground process / WSL domain to an icon + accent color
local function badge_for(pane_info)
  local proc = (pane_info.foreground_process_name or ''):lower()
  proc = proc:match('([^/\\]+)$') or proc
  proc = proc:gsub('%.exe$', '')

  local domain = pane_info.domain_name or ''

  -- WSL domains win — inside WSL the process is usually 'bash' or 'init'
  if domain == 'WSL:Debian'  then return ICON.DEBIAN, colors.red end
  if domain:find('^WSL:')    then return ICON.TUX,    colors.yellow end

  if proc == 'nvim' or proc == 'vim' or proc == 'vi'
                                       then return ICON.VIM,        colors.green end
  if proc == 'pwsh' or proc == 'powershell'
                                       then return ICON.POWERSHELL, colors.blue end
  if proc == 'cmd'                     then return ICON.CMD,        colors.subtext0 end
  if proc == 'bash' or proc == 'sh'    then return ICON.BASH,       colors.peach end
  if proc == 'fish'                    then return ICON.FISH,       colors.teal end
  if proc == 'zsh'                     then return ICON.BASH,       colors.peach end
  if proc == 'node'                    then return ICON.NODE,       colors.green end
  if proc == 'python' or proc == 'python3' or proc == 'py'
                                       then return ICON.PYTHON,     colors.yellow end
  if proc == 'git'                     then return ICON.GIT,        colors.peach end
  if proc == 'docker'                  then return ICON.DOCKER,     colors.sapphire end
  if proc == 'ssh'                     then return ICON.SSH,        colors.mauve end
  if proc == 'btop' or proc == 'htop' or proc == 'top'
                                       then return ICON.CHART,      colors.green end
  if proc == 'claude'                  then return ICON.CLAUDE,     colors.peach end

  return ICON.TERMINAL, colors.subtext0
end

function M.apply(config)
  config.use_fancy_tab_bar = false
  config.tab_bar_at_bottom = false
  config.hide_tab_bar_if_only_one_tab = false
  config.show_new_tab_button_in_tab_bar = true
  config.tab_max_width = 40
  config.show_tab_index_in_tab_bar = false

  config.colors = config.colors or {}
  config.colors.tab_bar = {
    background = colors.crust,
    new_tab       = { bg_color = colors.crust,    fg_color = colors.overlay0 },
    new_tab_hover = { bg_color = colors.surface0, fg_color = colors.text },
  }

  local LEFT_ROUND  = utf8.char(0xe0b6)  --
  local RIGHT_ROUND = utf8.char(0xe0b4)  --

  wezterm.on('format-tab-title', function(tab, tabs, panes, conf, hover, max_width)
    local idx = tab.tab_index + 1
    local title = tab.active_pane.title or ''
    title = title:gsub('^Copy mode: ', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #title > 26 then
      title = title:sub(1, 25) .. '…'
    end

    local icon, accent = badge_for(tab.active_pane)
    local is_active = tab.is_active

    -- Inactive tabs blend into the bar; active tabs lift on surface1
    -- with shell-coloured rounded edges. No coloured number pill — too noisy.
    local bg   = is_active and colors.surface1 or colors.mantle
    local fg   = is_active and colors.text     or colors.subtext0
    local edge = is_active and accent          or colors.mantle

    local pane_marker = ''
    if #tab.panes > 1 then
      pane_marker = '  ' .. utf8.char(0xf0c9) .. #tab.panes
    end

    return {
      { Background = { Color = colors.crust } },
      { Foreground = { Color = edge } },
      { Text = LEFT_ROUND },
      { Background = { Color = bg } },
      { Foreground = { Color = accent } },
      { Text = ' ' .. icon .. ' ' },
      { Foreground = { Color = colors.overlay0 } },
      { Text = idx .. ' ' },
      { Foreground = { Color = fg } },
      { Text = title .. pane_marker .. ' ' },
      { Background = { Color = colors.crust } },
      { Foreground = { Color = edge } },
      { Text = RIGHT_ROUND },
    }
  end)

  -- Right status: gradient powerline (workspace, time, host)
  -- Inspired by https://alexplescan.com/posts/2024/08/10/wezterm/
  local SOLID_LEFT_ARROW = utf8.char(0xe0b2)

  local function segments_for_status(window)
    return {
      utf8.char(0xf07c)  .. ' ' .. window:active_workspace(),  -- nf-fa-folder_open
      utf8.char(0xf00f0) .. ' ' .. wezterm.strftime('%a %d %b  %H:%M'),  -- nf-md-calendar_clock
      utf8.char(0xf109)  .. ' ' .. wezterm.hostname(),  -- nf-fa-laptop
    }
  end

  wezterm.on('update-status', function(window, _pane)
    local segments = segments_for_status(window)
    local palette = window:effective_config().resolved_palette
    local bg = wezterm.color.parse(palette.background or colors.base)
    local fg = palette.foreground or colors.text

    local gradient_to = bg
    local gradient_from = bg:lighten(0.18)

    local gradient = wezterm.color.gradient(
      { orientation = 'Horizontal', colors = { gradient_from, gradient_to } },
      #segments
    )

    local elements = {}
    for i, seg in ipairs(segments) do
      if i == 1 then
        table.insert(elements, { Background = { Color = 'none' } })
      end
      table.insert(elements, { Foreground = { Color = gradient[i] } })
      table.insert(elements, { Text = SOLID_LEFT_ARROW })
      table.insert(elements, { Background = { Color = gradient[i] } })
      table.insert(elements, { Foreground = { Color = fg } })
      table.insert(elements, { Text = ' ' .. seg .. ' ' })
    end

    window:set_right_status(wezterm.format(elements))
  end)
end

return M
