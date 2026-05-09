-- =============================================================================
-- Hammerspoon config
--
-- Pairs with ~/.vimrc (used as a SKK Japanese-input pad). The pad runs in
-- iTerm2's hotkey window; on commit it yanks the line into the system
-- clipboard, opens hammerspoon://nvim-ime-commit, and quits. The iTerm2
-- profile closes the window on session end, so all this URL handler has to
-- do is refocus the window the user came from and replay Cmd+V there.
--
-- (The URL is still named nvim-ime-commit for compatibility; the pad
-- itself migrated from Neovim to plain Vim a while ago.)
-- =============================================================================

-- EmmyLua Spoon writes ~/.hammerspoon/Spoons/EmmyLua.spoon/annotations/ on
-- load; lua_ls picks those up as a library (see .luarc.json) so hs.* gets
-- proper completion and warnings.
hs.loadSpoon("EmmyLua")

-- -----------------------------------------------------------------------------
-- Constants.
-- -----------------------------------------------------------------------------
local ITERM_BUNDLE  = "com.googlecode.iterm2"
local POLL_INTERVAL = 0.5
local PASTE_DELAY   = 0.15
local COMMIT_URL    = "nvim-ime-commit"

-- Apps whose windows should never be treated as a paste target. They are
-- typically opened only momentarily for inspection (Hammerspoon Console
-- etc.) and shouldn't clobber the real previous window.
local EXCLUDED_APPS = {
  ["Hammerspoon"] = true,
}

-- The hotkey window's session passes through several titles depending on
-- which point of the launch we look at it ("zsh"/"bash"/"fish" while the
-- shell is starting, "vim"/"nvim" once the editor takes over,
-- "ime-scratch" once the scratch buffer is loaded, "open" while the URL
-- handler is firing, "" during transitions). We refuse to treat any
-- iTerm2 window with one of these titles as a paste target.
local IME_TRANSIENT_TITLES = {
  ["vim"]  = true, ["nvim"] = true,
  ["zsh"]  = true, ["bash"] = true, ["fish"] = true,
  ["open"] = true,
  [""]     = true,
}

-- -----------------------------------------------------------------------------
-- Window tracking. Two pieces of state:
--   previousWindow      : most recent focused window across all apps that
--                         we'd consider a valid paste target.
--   previousITermWindow : most recent normal (non-IME) iTerm2 window. Used
--                         as a fallback when previousWindow no longer
--                         exists or got rejected.
-- -----------------------------------------------------------------------------
local previousWindow      = nil
local previousITermWindow = nil
local hotkeyWindowId      = nil

local function looksLikeImeWindow(win)
  if hotkeyWindowId and win:id() == hotkeyWindowId then return true end
  local title = win:title() or ""
  if title:match("ime%-scratch") then return true end
  return IME_TRANSIENT_TITLES[title] == true
end

local function refreshTracking()
  -- Maintain previousITermWindow: walk iTerm2's visible windows and pick
  -- the first non-IME one. While we're here, learn the hotkey window's id
  -- whenever we happen to see it focused so we can short-circuit the
  -- title-based check on subsequent passes.
  local iterm = hs.application.get(ITERM_BUNDLE)
  if iterm then
    local focusedInIterm = iterm:focusedWindow()
    if focusedInIterm and looksLikeImeWindow(focusedInIterm) then
      hotkeyWindowId = focusedInIterm:id()
    end
    for _, win in ipairs(iterm:allWindows()) do
      if win:isVisible() and not looksLikeImeWindow(win) then
        previousITermWindow = win
        break
      end
    end
  end

  -- Maintain previousWindow: the focused window of any non-excluded,
  -- non-IME app. We DO accept regular iTerm2 windows so committing from
  -- the hotkey window after working in tmux returns us to that tmux
  -- window, not whatever non-iTerm2 app we'd seen earlier.
  local focused = hs.window.focusedWindow()
  if not focused then return end
  local app = focused:application()
  if not app then return end
  local appName = app:name() or ""
  if EXCLUDED_APPS[appName] then return end
  if app:bundleID() == ITERM_BUNDLE and looksLikeImeWindow(focused) then
    return
  end
  previousWindow = focused
end

-- The watchers must outlive this file's load. Hammerspoon's lua may GC
-- unused locals at any time (the `---@diagnostic disable-next-line` only
-- quiets the linter, it doesn't change Lua's behaviour), and we did see
-- the watchers fall silent mid-session when they were locals. Pinning
-- them on _G gives them a strong reference for the entire process.
_G.imeAppWatcher = hs.application.watcher.new(function(_, eventType, _)
  if eventType == hs.application.watcher.activated then
    refreshTracking()
  end
end)
_G.imeAppWatcher:start()

-- App-activation events don't fire when switching between two windows of
-- the same app (e.g. Slack -> iTerm2 main vs Slack -> iTerm2 hotkey), so
-- back the watcher up with periodic polling.
_G.imeWindowPoller = hs.timer.doEvery(POLL_INTERVAL, refreshTracking)

-- -----------------------------------------------------------------------------
-- URL handler: hammerspoon://<COMMIT_URL>
-- -----------------------------------------------------------------------------
local function freshHandle(win)
  if not win then return nil end
  local id = win:id()
  if not id then return nil end
  return hs.window.get(id)
end

local function chooseTarget()
  -- Default: the most recent valid window across all apps.
  local target = freshHandle(previousWindow)

  -- Defensive: if previousWindow somehow ended up pointing at the IME
  -- hotkey window (race conditions during launch), drop it and fall
  -- through to the iTerm2 fallback below.
  if target and target:application()
      and target:application():bundleID() == ITERM_BUNDLE
      and looksLikeImeWindow(target) then
    target = nil
  end

  if not target then
    target = freshHandle(previousITermWindow)
  end
  return target
end

hs.urlevent.bind(COMMIT_URL, function()
  local target = chooseTarget()

  -- Focus first, then paste. Vim-ime is concurrently quitting and the
  -- iTerm2 profile closes the window on session end, so the hotkey
  -- window fades out by itself; if we focus the target before that
  -- fade completes the user mostly doesn't see any iTerm2 flash.
  if target then target:focus() end

  -- Small delay so macOS finishes settling the focus change before the
  -- synthetic Cmd+V; without it the keystroke can be delivered to the
  -- still-vanishing hotkey window.
  hs.timer.doAfter(PASTE_DELAY, function()
    hs.eventtap.keyStroke({ "cmd" }, "v", 0)
  end)
end)

-- -----------------------------------------------------------------------------
-- Auto-reload when this file changes. Pinned on _G for the same reason
-- as the watchers above.
-- -----------------------------------------------------------------------------
_G.imeConfigWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/",
  function(files)
    for _, file in ipairs(files) do
      if file:match("%.lua$") then
        hs.reload()
        return
      end
    end
  end)
_G.imeConfigWatcher:start()

hs.alert.show("Hammerspoon ready")
