-- Force OSC 52 clipboard when nvim is running over SSH (or under tmux on a
-- remote box). Without this, neovim falls back to pbcopy/xsel/wl-copy on
-- whichever host nvim itself runs on — that updates the *remote* clipboard,
-- not the local Mac one in front of the user.
--
-- The path we want for an SSH session is:
--   nvim --OSC52--> inner tmux --passthrough--> outer tmux --set-clipboard-->
--   iTerm2 --> macOS pasteboard
--
-- nvim 0.10+ ships an OSC 52 provider in runtime/. It tries to auto-enable
-- via DA1 / XTGETTCAP, but tmux does not advertise OSC 52 in its DA1
-- response, so the autodetect silently fails inside tmux. We force the
-- termfeatures flag instead.

local function on_ssh()
  return vim.env.SSH_TTY ~= nil
    or vim.env.SSH_CONNECTION ~= nil
    or vim.env.SSH_CLIENT ~= nil
end

if not on_ssh() then
  return
end

local termfeatures = vim.g.termfeatures or {}
termfeatures.osc52 = true
vim.g.termfeatures = termfeatures

-- Pin the clipboard tool to nvim's built-in OSC 52 helpers, otherwise an
-- installed pbcopy / xsel on the remote host wins and we'd update the
-- wrong clipboard.
vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  paste = {
    ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
    ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
  },
}
