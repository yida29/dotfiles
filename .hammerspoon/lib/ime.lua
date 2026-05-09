-- =============================================================================
-- Pure helpers for the IME hotkey-window logic. Kept separate from init.lua
-- so they can be unit-tested without booting Hammerspoon.
--
-- Everything here takes window-like values as parameters; nothing reaches
-- out to global state or hs.* APIs.
-- =============================================================================

local M = {}

-- The hotkey window's title cycles through several values during launch
-- ("zsh"/"bash"/"fish" while the shell is starting, "vim"/"nvim" once
-- the editor takes over, "ime-scratch" once the scratch buffer loads,
-- "open" while the URL handler fires, "" during transitions). We refuse
-- to treat any iTerm2 window with one of these titles as a paste target.
M.IME_TRANSIENT_TITLES = {
  ["vim"]  = true, ["nvim"] = true,
  ["zsh"]  = true, ["bash"] = true, ["fish"] = true,
  ["open"] = true,
  [""]     = true,
}

-- A window object passed in here only needs two methods: id() and title().
function M.looksLikeImeWindow(win, hotkeyWindowId)
  if not win then return false end
  if hotkeyWindowId and win:id() == hotkeyWindowId then return true end
  local title = win:title() or ""
  if title:match("ime%-scratch") then return true end
  -- Whitespace-only titles (incl. " ", "  ", "\t") are also a transient
  -- state of the hotkey window before its session settles. Strip first.
  if title:match("^%s*$") then return true end
  return M.IME_TRANSIENT_TITLES[title] == true
end

-- Pick which window the URL handler should focus + paste into.
--
-- Args (table form so test calls read clearly):
--   previousWindow      : last-seen focused window of any non-IME app
--   previousITermWindow : last-seen non-IME iTerm2 window
--   hotkeyWindowId      : id of the IME hotkey window (or nil)
--   itermBundle         : iTerm2's bundle id (passed in to keep this
--                         module bundle-id agnostic)
--   refresh             : function(win) -> win/nil; "fresh handle" lookup
--                         that returns nil if the window is gone. Tests
--                         can pass `function(w) return w end` to short-
--                         circuit it; init.lua passes hs.window.get-based
--                         freshHandle.
--
-- Returns the chosen target window, or nil if nothing usable remains.
function M.chooseTarget(opts)
  local refresh = opts.refresh or function(w) return w end
  local target  = refresh(opts.previousWindow)

  -- If previousWindow somehow ended up pointing at the IME hotkey
  -- window, drop it and fall through to the iTerm2 fallback.
  if target then
    local app = target.application and target:application() or nil
    local bundle = app and app.bundleID and app:bundleID() or nil
    if bundle == opts.itermBundle and M.looksLikeImeWindow(target, opts.hotkeyWindowId) then
      target = nil
    end
  end

  if not target then
    target = refresh(opts.previousITermWindow)
  end
  return target
end

return M
