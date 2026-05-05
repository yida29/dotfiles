-- =============================================================================
-- Hammerspoon config
-- =============================================================================

-- -----------------------------------------------------------------------------
-- URL handler: hammerspoon://nvim-ime-commit
--
-- Triggered by nvim-ime when the user confirms input (Cmd+Enter).
-- nvim-ime has already yanked the text into the system clipboard before
-- calling this handler. Our job:
--   1. Hide the iTerm2 hotkey window so focus returns to the previous app.
--   2. Wait for the focus to settle.
--   3. Send Cmd+V to paste into the now-frontmost app.
-- -----------------------------------------------------------------------------
hs.urlevent.bind("nvim-ime-commit", function(eventName, params)
  -- Toggle the iTerm2 hotkey window off via AppleScript. iTerm2 exposes a
  -- "select" command for hotkey windows, but the simplest approach is to
  -- activate whichever app was previously frontmost. Hammerspoon already
  -- knows the previous app via hs.application.frontmostApplication() before
  -- we run, so we cache it during a focus watcher (see below).
  local prev = previousApp
  if prev then
    prev:activate()
  else
    -- Fallback: hide iTerm2 so the OS picks the next app underneath.
    local iterm = hs.application.get("iTerm2")
    if iterm then
      iterm:hide()
    end
  end

  -- Give the focus a moment to settle before sending Cmd+V.
  hs.timer.doAfter(0.15, function()
    hs.eventtap.keyStroke({ "cmd" }, "v", 0)
  end)
end)

-- -----------------------------------------------------------------------------
-- Track the previously-frontmost app so we can return to it on commit.
-- Whenever a new app becomes frontmost, the *old* one is recorded as
-- `previousApp` (unless the new one is iTerm2 itself).
-- -----------------------------------------------------------------------------
previousApp = nil
local lastApp = hs.application.frontmostApplication()

appWatcher = hs.application.watcher.new(function(name, eventType, app)
  if eventType ~= hs.application.watcher.activated then
    return
  end
  if app:bundleID() == "com.googlecode.iterm2" then
    -- iTerm2 just became active. Remember whatever was active before.
    if lastApp and lastApp:bundleID() ~= "com.googlecode.iterm2" then
      previousApp = lastApp
    end
  end
  lastApp = app
end)
appWatcher:start()

-- -----------------------------------------------------------------------------
-- Reload helper: edit ~/.hammerspoon/init.lua and run :w to reload automatically.
-- -----------------------------------------------------------------------------
configWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", function(files)
  for _, file in ipairs(files) do
    if file:match("%.lua$") then
      hs.reload()
      return
    end
  end
end)
configWatcher:start()

hs.alert.show("Hammerspoon ready")
