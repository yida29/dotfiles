-- =============================================================================
-- Hammerspoon config
--
-- Pairs with ~/.config/nvim-ime/init.lua. nvim-ime runs in iTerm2's hotkey
-- window; when the user confirms input, it yanks the line into the system
-- clipboard and opens hammerspoon://nvim-ime-commit. We then dismiss the
-- hotkey window, refocus the window the user was looking at before, and
-- replay Cmd+V there.
-- =============================================================================

local ITERM_BUNDLE = "com.googlecode.iterm2"
local IME_HOTKEY = { mods = { "cmd" }, key = "j" }
local POLL_INTERVAL = 0.5
local HIDE_DELAY = 0.15
local PASTE_DELAY = 0.15

-- Apps whose windows should never be treated as a paste target. They are
-- typically opened only momentarily for inspection (Hammerspoon Console
-- etc.) and shouldn't clobber the real previous window.
local EXCLUDED_APPS = {
  ["Hammerspoon"] = true,
}

-- -----------------------------------------------------------------------------
-- Track two windows:
--   * `previousWindow`         – the most recent window of any (non-excluded)
--                                app. This is what we return to by default.
--   * `previousITermWindow`    – the most recent normal iTerm2 window. We
--                                fall back to this when `previousWindow`
--                                points at the iTerm2 hotkey window itself
--                                (i.e. nvim-ime), since you can't paste into
--                                the buffer you're committing from.
-- -----------------------------------------------------------------------------
local previousWindow = nil
local previousITermWindow = nil
local hotkeyWindowId = nil

local function looksLikeImeWindow(win)
  if hotkeyWindowId and win:id() == hotkeyWindowId then return true end
  -- The nvim-ime buffer is ime-scratch.md, but a freshly-launched nvim or a
  -- nameless buffer also gives "nvim" / "" as the window title. Either way,
  -- we never want to paste into it.
  local title = win:title() or ""
  return title:match("ime%-scratch") ~= nil or title == "nvim" or title == ""
end

local function refreshTracking()
  -- Track the most-recent normal iTerm2 window separately so we always have
  -- a fallback even when `previousWindow` happens to point at the hotkey
  -- window.
  local iterm = hs.application.get(ITERM_BUNDLE)
  if iterm then
    -- Capture the hotkey window's id whenever we see it focused so that
    -- subsequent passes reliably skip it.
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

  -- Track the most-recent focused window across *all* apps.
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

appWatcher = hs.application.watcher.new(function(_, eventType, _)
  if eventType == hs.application.watcher.activated then
    refreshTracking()
  end
end)
appWatcher:start()

-- App-activation events alone don't fire when switching between two iTerm2
-- windows in the same app, so poll as well.
windowPoller = hs.timer.doEvery(POLL_INTERVAL, refreshTracking)

-- -----------------------------------------------------------------------------
-- URL handler: hammerspoon://nvim-ime-commit
-- -----------------------------------------------------------------------------
local function freshHandle(win)
  if not win then return nil end
  local id = win:id()
  if not id then return nil end
  return hs.window.get(id)
end

hs.urlevent.bind("nvim-ime-commit", function()
  -- Default: return to whatever window the user was on. If that happens to
  -- be the iTerm2 hotkey window (nvim-ime), fall back to the most-recent
  -- normal iTerm2 window instead.
  local target = freshHandle(previousWindow)
  if target and target:application()
      and target:application():bundleID() == ITERM_BUNDLE
      and looksLikeImeWindow(target) then
    target = nil
  end
  if not target then
    target = freshHandle(previousITermWindow)
  end

  -- Toggle iTerm2's hotkey window off by re-sending its hotkey.
  hs.eventtap.keyStroke(IME_HOTKEY.mods, IME_HOTKEY.key, 0)

  hs.timer.doAfter(HIDE_DELAY, function()
    if target then target:focus() end
    hs.timer.doAfter(PASTE_DELAY, function()
      hs.eventtap.keyStroke({ "cmd" }, "v", 0)
    end)
  end)
end)

-- -----------------------------------------------------------------------------
-- Auto-reload when this file changes.
-- -----------------------------------------------------------------------------
configWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/",
  function(files)
    for _, file in ipairs(files) do
      if file:match("%.lua$") then
        hs.reload()
        return
      end
    end
  end)
configWatcher:start()

hs.alert.show("Hammerspoon ready")
