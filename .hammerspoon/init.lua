-- =============================================================================
-- Hammerspoon config
--
-- Pairs with ~/.config/nvim-ime/init.lua. nvim-ime runs in iTerm2's hotkey
-- window; when the user confirms input, it yanks the line into the system
-- clipboard and opens hammerspoon://nvim-ime-commit. We then dismiss the
-- hotkey window, refocus the iTerm2 window the user was looking at before,
-- and replay Cmd+V there.
-- =============================================================================

local ITERM_BUNDLE = "com.googlecode.iterm2"
local IME_HOTKEY = { mods = { "cmd", "shift" }, key = "j" }
local POLL_INTERVAL = 0.5
local HIDE_DELAY = 0.15
local PASTE_DELAY = 0.15

-- -----------------------------------------------------------------------------
-- Track the most-recent normal iTerm2 window so commit can hand the pasted
-- text back to it. We exclude the hotkey window where nvim-ime lives.
-- -----------------------------------------------------------------------------
local previousITermWindow = nil
local hotkeyWindowId = nil

local function looksLikeImeWindow(win)
  if hotkeyWindowId and win:id() == hotkeyWindowId then return true end
  -- The nvim-ime buffer is ime-scratch.md, but a freshly-launched nvim or a
  -- nameless buffer also gives "nvim" / "" as the window title. Both should
  -- be excluded as paste targets.
  local title = win:title() or ""
  return title:match("ime%-scratch") ~= nil or title == "nvim" or title == ""
end

local function refreshPreviousITermWindow()
  local iterm = hs.application.get(ITERM_BUNDLE)
  if not iterm then return end

  -- Capture the hotkey window id whenever we see it focused, so subsequent
  -- polls reliably skip it.
  local focused = iterm:focusedWindow()
  if focused and looksLikeImeWindow(focused) then
    hotkeyWindowId = focused:id()
  end

  for _, win in ipairs(iterm:allWindows()) do
    if win:isVisible() and not looksLikeImeWindow(win) then
      previousITermWindow = win
      return
    end
  end
end

appWatcher = hs.application.watcher.new(function(_, eventType, _)
  if eventType == hs.application.watcher.activated then
    refreshPreviousITermWindow()
  end
end)
appWatcher:start()

-- App-activation events alone don't fire when switching between two iTerm2
-- windows in the same app, so poll as well.
windowPoller = hs.timer.doEvery(POLL_INTERVAL, refreshPreviousITermWindow)

-- -----------------------------------------------------------------------------
-- URL handler: hammerspoon://nvim-ime-commit
-- -----------------------------------------------------------------------------
hs.urlevent.bind("nvim-ime-commit", function()
  -- Re-fetch by id so we don't hold onto a stale window handle.
  local target = nil
  if previousITermWindow then
    local id = previousITermWindow:id()
    if id then target = hs.window.get(id) end
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
