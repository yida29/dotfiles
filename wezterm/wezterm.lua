-- =============================================================================
-- WezTerm config — the Windows (WSL) counterpart of iterm2/.
--
-- Colors, font and transparency are ported from the iTerm2 "Default"
-- profile. On Windows install.sh copies this file to %USERPROFILE%\.wezterm.lua
-- (Windows can't follow WSL symlinks), so re-run install.sh after editing.
--
-- When VIM_IME_COMMIT is set, this process is the vim-ime pad launched by
-- windows/vim-ime.ahk (the equivalent of iTerm2's "Japanese Input" hotkey
-- profile): big font, small window, runs `vim-ime` in WSL and closes on exit.
-- =============================================================================
local wezterm = require("wezterm")
local config = wezterm.config_builder()

local is_windows = wezterm.target_triple:find("windows") ~= nil
local ime_commit = os.getenv("VIM_IME_COMMIT")

-- -----------------------------------------------------------------------------
-- Colors (iTerm2 Default profile; separate light / dark variants).
-- -----------------------------------------------------------------------------
local ansi = { "#14191e", "#b43c2a", "#00c200", "#c7c400", "#2744c7", "#c040be", "#00c5c7", "#c7c7c7" }
local brights = { "#686868", "#dd7975", "#58e790", "#ece100", "#a7abf2", "#e17ee1", "#60fdff", "#ffffff" }

config.color_schemes = {
  ["iTerm2 Dark (dotfiles)"] = {
    foreground = "#dcdcdc",
    background = "#15191f",
    cursor_bg = "#ffffff",
    cursor_fg = "#000000",
    cursor_border = "#ffffff",
    selection_bg = "#b3d7ff",
    selection_fg = "#000000",
    ansi = ansi,
    brights = brights,
  },
  ["iTerm2 Light (dotfiles)"] = {
    foreground = "#101010",
    background = "#fafafa",
    cursor_bg = "#000000",
    cursor_fg = "#ffffff",
    cursor_border = "#000000",
    selection_bg = "#b3d7ff",
    selection_fg = "#000000",
    ansi = ansi,
    brights = brights,
  },
}

-- Always dark: Windows is usually in light mode, and the light variant
-- through a transparent window looks washed out.
config.color_scheme = "iTerm2 Dark (dotfiles)"

-- -----------------------------------------------------------------------------
-- Font / window.
-- -----------------------------------------------------------------------------
config.font = wezterm.font_with_fallback({
  "JetBrainsMonoNL Nerd Font Mono",
  "BIZ UDGothic", -- Windows Japanese fallback
  "Hiragino Sans", -- macOS Japanese fallback
})
config.font_size = 14
config.window_background_opacity = 0.85
if is_windows then
  -- Blur whatever shows through instead of plain see-through.
  config.win32_system_backdrop = "Acrylic"
end
config.initial_cols = 80
config.initial_rows = 25
-- tmux does the tabbing.
config.hide_tab_bar_if_only_one_tab = true

-- -----------------------------------------------------------------------------
-- Tabs: Alt+1..8 jump to that tab, Alt+9 to the last one, Alt+T opens one
-- (iTerm2's Cmd+N / Cmd+T;
-- Alt sits where Cmd is on a Mac keyboard).
-- -----------------------------------------------------------------------------
config.keys = {}
for i = 1, 8 do
  table.insert(config.keys, { key = tostring(i), mods = "ALT", action = wezterm.action.ActivateTab(i - 1) })
end
table.insert(config.keys, { key = "9", mods = "ALT", action = wezterm.action.ActivateTab(-1) })
-- Alt+T: new tab (iTerm2's Cmd+T), in the same domain as the current pane (WSL).
table.insert(config.keys, { key = "t", mods = "ALT", action = wezterm.action.SpawnTab("CurrentPaneDomain") })

-- bin/sshs tabs publish sshs_host / sshs_color ("r g b") as user vars;
-- paint those tabs in the host's color (iTerm2 used OSC 6 tab colors).
wezterm.on("format-tab-title", function(tab)
  local vars = tab.active_pane.user_vars or {}
  local host = vars.sshs_host
  if not host or host == "" then
    return nil
  end
  local title = string.format(" %d: %s ", tab.tab_index + 1, host)
  local r, g, b = (vars.sshs_color or ""):match("^(%d+) (%d+) (%d+)$")
  if not r then
    return title
  end
  r, g, b = tonumber(r), tonumber(g), tonumber(b)
  local bg = string.format("#%02x%02x%02x", r, g, b)
  local fg = (0.299 * r + 0.587 * g + 0.114 * b) > 150 and "#000000" or "#ffffff"
  local cells = { { Background = { Color = bg } }, { Foreground = { Color = fg } } }
  if not tab.is_active then
    table.insert(cells, { Attribute = { Intensity = "Half" } })
  end
  table.insert(cells, { Text = title })
  return cells
end)

-- -----------------------------------------------------------------------------
-- Windows: open WSL by default, with truecolor passed through.
-- -----------------------------------------------------------------------------
-- WEZTERM_PANE: lets `wezterm cli` inside WSL (bin/sshs) target this window.
local wslenv = { "COLORTERM", "WEZTERM_PANE" }
if os.getenv("WSLENV") and os.getenv("WSLENV") ~= "" then
  table.insert(wslenv, os.getenv("WSLENV"))
end
if ime_commit then
  -- /p: translate the Windows path to /mnt/c/... inside WSL.
  table.insert(wslenv, "VIM_IME_COMMIT/p")
end
config.set_environment_variables = {
  COLORTERM = "truecolor",
  WSLENV = table.concat(wslenv, ":"),
}

if is_windows then
  local domains = wezterm.default_wsl_domains()
  for _, d in ipairs(domains) do
    d.default_cwd = "~"
  end
  config.wsl_domains = domains
  for _, d in ipairs(domains) do
    if d.name:find("^WSL:Ubuntu") then
      config.default_domain = d.name
      break
    end
  end
end

-- -----------------------------------------------------------------------------
-- vim-ime pad mode (see windows/vim-ime.ahk).
-- -----------------------------------------------------------------------------
if ime_commit then
  config.default_domain = "local"
  config.default_prog = { "wsl.exe", "--cd", "~", "--exec", "bash", "-lc", "vim-ime" }
  config.font_size = 20
  config.initial_rows = 12
  config.enable_tab_bar = false
  config.window_close_confirmation = "NeverPrompt"
  config.exit_behavior = "Close"
end

return config
