-- =============================================================================
-- nvim-ime: minimal Neovim config used as a SKK Japanese-input pad.
--
-- Pairs with ~/.hammerspoon/init.lua. Lives inside iTerm2's hotkey window
-- (profile "Japanese Input"); hitting Cmd+J pops up a Neovim instance that
-- starts already in skkeleton's hira mode at the bottom of a scratch file.
-- After typing, hitting <CR> in normal mode commits the line back to the
-- previous app (Hammerspoon does the actual focus + paste) and quits.
--
-- Quitting on commit is intentional: the iTerm2 profile is set to
-- "Close Sessions On End", and the short-lived-session warning is suppressed
-- via NeverWarnAboutShortLivedSessions_<GUID>. So every Cmd+J spawns a fresh
-- nvim, which guarantees skkeleton initializes cleanly each time.
--
-- Launch manually with: NVIM_APPNAME=nvim-ime nvim
-- =============================================================================

local SCRATCH_FILE = "~/Documents/ime-scratch.md"
local SKK_DICT = "~/.skk/SKK-JISYO.L"
local COMMIT_URL = "hammerspoon://nvim-ime-commit"

-- -----------------------------------------------------------------------------
-- Bootstrap lazy.nvim.
-- -----------------------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- -----------------------------------------------------------------------------
-- Minimal UI.
-- -----------------------------------------------------------------------------
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.signcolumn = "no"
vim.opt.laststatus = 2
vim.opt.cmdheight = 1
vim.opt.ruler = false
vim.opt.showmode = false
vim.opt.showcmd = false
vim.opt.clipboard = "unnamedplus"
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

vim.keymap.set("i", "<C-c>", "<Esc>", { noremap = true })

-- -----------------------------------------------------------------------------
-- Plugins.
-- -----------------------------------------------------------------------------
require("lazy").setup({
  { "vim-denops/denops.vim", lazy = false },
  {
    "vim-skk/skkeleton",
    dependencies = { "vim-denops/denops.vim" },
    config = function()
      -- enable (not toggle): pressing <C-j> always lands in hira regardless
      -- of current state. Disable by leaving insert mode (<Esc>).
      vim.keymap.set({ "i", "c" }, "<C-j>", "<Plug>(skkeleton-enable)")
      vim.api.nvim_create_autocmd("User", {
        pattern = "skkeleton-initialize-pre",
        callback = function()
          vim.fn["skkeleton#config"]({
            globalDictionaries = { { SKK_DICT, "euc-jp" } },
          })
        end,
      })
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "filename" },
        lualine_c = {},
        lualine_x = {
          {
            cond = function() return vim.fn["skkeleton#is_enabled"]() end,
            function() return vim.fn["skkeleton#mode"]() end,
            color = { fg = "#ff9e64", gui = "bold" },
          },
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },
})

-- -----------------------------------------------------------------------------
-- Helpers.
-- -----------------------------------------------------------------------------
local function ensure_trailing_blank_line(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines > 0 and lines[#lines] ~= "" then
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
  end
end

local function open_scratch_at_bottom()
  local scratch = vim.fn.expand(SCRATCH_FILE)
  if vim.fn.filereadable(scratch) == 0 then
    vim.fn.writefile({}, scratch)
  end
  vim.cmd("edit " .. vim.fn.fnameescape(scratch))
  ensure_trailing_blank_line(0)
  vim.cmd("normal! G")
  vim.schedule(function() vim.cmd("startinsert!") end)
end

local function enter_hira()
  vim.schedule(function()
    if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i" then
      vim.cmd("startinsert!")
    end
    -- Run via vim.cmd so the dict literal is parsed by Vimscript itself
    -- (a Lua {} crosses the bridge as a List, which skkeleton#handle rejects).
    pcall(vim.cmd, [[silent! call skkeleton#handle('enable', {})]])
  end)
end

local function commit_and_quit()
  vim.fn.jobstart({ "open", "-g", COMMIT_URL }, { detach = true })
  vim.cmd("silent! wall")
  vim.cmd("qa!")
end

-- -----------------------------------------------------------------------------
-- Startup: open scratch, jump to the bottom, and turn SKK on once denops
-- has finished loading skkeleton.
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("VimEnter", { callback = open_scratch_at_bottom })

vim.api.nvim_create_autocmd("User", {
  pattern = "DenopsPluginPost:skkeleton",
  callback = enter_hira,
})

-- -----------------------------------------------------------------------------
-- Commit (normal/visual <CR>): yank current line / selection without trailing
-- newline, hand off to Hammerspoon, then quit so the next Cmd+J starts fresh.
-- -----------------------------------------------------------------------------
vim.keymap.set("n", "<CR>", function()
  vim.fn.setreg("+", vim.api.nvim_get_current_line())
  commit_and_quit()
end, { desc = "Commit current line to previous app" })

vim.keymap.set("v", "<CR>", function()
  vim.cmd('normal! "+y')
  vim.fn.setreg("+", (vim.fn.getreg("+"):gsub("\n$", "")))
  commit_and_quit()
end, { desc = "Commit selection to previous app" })

-- -----------------------------------------------------------------------------
-- Auto-save the scratch buffer so :qa! never has to discard unsaved edits.
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "FocusLost" }, {
  callback = function()
    if vim.bo.modified and vim.bo.buftype == "" and vim.fn.expand("%") ~= "" then
      vim.cmd("silent! write")
    end
  end,
})
