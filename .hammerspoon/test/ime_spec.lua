-- Run with: cd ~/dotfiles/.hammerspoon && busted test/
--
-- Pure-Lua tests for lib/ime.lua. No Hammerspoon, no real windows — we
-- pass plain tables that mimic the bits of the hs window/application API
-- the helpers actually touch.

package.path = "./?.lua;" .. package.path

local ime = require("lib.ime")

-- -----------------------------------------------------------------------------
-- Helpers: tiny window/app stubs.
-- -----------------------------------------------------------------------------
local function mkApp(bundleID)
  return {
    bundleID = function() return bundleID end,
  }
end

local function mkWin(opts)
  opts = opts or {}
  local app = opts.bundleID and mkApp(opts.bundleID) or nil
  return {
    _id    = opts.id,
    _title = opts.title or "",
    id          = function(self) return self._id end,
    title       = function(self) return self._title end,
    application = function() return app end,
  }
end

local ITERM = "com.googlecode.iterm2"

-- -----------------------------------------------------------------------------
-- looksLikeImeWindow
-- -----------------------------------------------------------------------------
describe("looksLikeImeWindow", function()
  it("rejects nil windows", function()
    assert.is_false(ime.looksLikeImeWindow(nil, nil))
  end)

  it("matches by cached hotkey window id", function()
    local win = mkWin({ id = 42, title = "anything-here" })
    assert.is_true(ime.looksLikeImeWindow(win, 42))
  end)

  it("does not match a different id", function()
    local win = mkWin({ id = 100, title = "tmux" })
    assert.is_false(ime.looksLikeImeWindow(win, 42))
  end)

  it("matches the ime-scratch title", function()
    local win = mkWin({ id = 1, title = "ime-scratch" })
    assert.is_true(ime.looksLikeImeWindow(win, nil))
  end)

  it("matches a path containing ime-scratch", function()
    local win = mkWin({ id = 1, title = "/Users/me/Documents/ime-scratch" })
    assert.is_true(ime.looksLikeImeWindow(win, nil))
  end)

  it("matches transient shell/editor titles", function()
    for _, title in ipairs({ "vim", "nvim", "zsh", "bash", "fish", "open", "" }) do
      local win = mkWin({ id = 1, title = title })
      assert.is_true(ime.looksLikeImeWindow(win, nil),
        "expected title '" .. title .. "' to be classified as IME")
    end
  end)

  it("rejects an ordinary tmux terminal", function()
    local win = mkWin({ id = 1, title = "tmux" })
    assert.is_false(ime.looksLikeImeWindow(win, nil))
  end)

  it("rejects an ordinary app window", function()
    local win = mkWin({ id = 1, title = "Slack — channel" })
    assert.is_false(ime.looksLikeImeWindow(win, nil))
  end)
end)

-- -----------------------------------------------------------------------------
-- chooseTarget
-- -----------------------------------------------------------------------------
describe("chooseTarget", function()
  local function call(opts)
    -- Default to identity refresh so a window passed in comes back out.
    opts.refresh = opts.refresh or function(w) return w end
    opts.itermBundle = opts.itermBundle or ITERM
    return ime.chooseTarget(opts)
  end

  it("returns previousWindow when it's valid", function()
    local slack = mkWin({ id = 1, title = "Slack", bundleID = "com.tinyspeck.slackmacgap" })
    local target = call({
      previousWindow      = slack,
      previousITermWindow = nil,
      hotkeyWindowId      = nil,
    })
    assert.are.equal(slack, target)
  end)

  it("returns nil when nothing is tracked", function()
    local target = call({
      previousWindow      = nil,
      previousITermWindow = nil,
      hotkeyWindowId      = nil,
    })
    assert.is_nil(target)
  end)

  it("falls back to previousITermWindow when previousWindow is gone", function()
    local stale = mkWin({ id = 1, title = "old" })
    local tmux  = mkWin({ id = 2, title = "tmux", bundleID = ITERM })
    local target = call({
      previousWindow      = stale,
      previousITermWindow = tmux,
      hotkeyWindowId      = nil,
      -- refresh treats stale as gone, tmux as still alive.
      refresh = function(w)
        if w == stale then return nil end
        return w
      end,
    })
    assert.are.equal(tmux, target)
  end)

  it("rejects previousWindow when it points at the hotkey IME window", function()
    -- Even though it's an iTerm2 window, the title says "vim" -> IME.
    local pad   = mkWin({ id = 1, title = "vim",  bundleID = ITERM })
    local tmux  = mkWin({ id = 2, title = "tmux", bundleID = ITERM })
    local target = call({
      previousWindow      = pad,
      previousITermWindow = tmux,
      hotkeyWindowId      = nil,
    })
    assert.are.equal(tmux, target)
  end)

  it("rejects by hotkeyWindowId regardless of title", function()
    local pad = mkWin({ id = 99, title = "tmux", bundleID = ITERM })
    local target = call({
      previousWindow      = pad,
      previousITermWindow = nil,
      hotkeyWindowId      = 99,
    })
    assert.is_nil(target)
  end)

  it("keeps a normal iTerm2 window as previousWindow", function()
    -- A regular iTerm2 window (title "tmux") should pass through; we
    -- only reject iTerm2 windows that look like the IME pad.
    local tmux = mkWin({ id = 1, title = "tmux", bundleID = ITERM })
    local target = call({
      previousWindow      = tmux,
      previousITermWindow = nil,
      hotkeyWindowId      = nil,
    })
    assert.are.equal(tmux, target)
  end)

  it("returns nil when both windows refresh to nil", function()
    local stale1 = mkWin({ id = 1, title = "x" })
    local stale2 = mkWin({ id = 2, title = "y" })
    local target = call({
      previousWindow      = stale1,
      previousITermWindow = stale2,
      hotkeyWindowId      = nil,
      refresh = function() return nil end,
    })
    assert.is_nil(target)
  end)
end)
