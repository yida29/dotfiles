-- =============================================================================
-- nvim-ime: Minimal Neovim config for Japanese input via skkeleton.
--
-- Pairs with ~/.hammerspoon/init.lua. Intended to live in iTerm2's hotkey
-- window so the user can pop up a Japanese-input pad from anywhere.
--
-- Launch with: NVIM_APPNAME=nvim-ime nvim
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
-- Minimal UI: no swap/backup files (the always-on session would collide
-- with itself), and most chrome stripped down to just lualine.
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

-- Treat Ctrl+C as Escape in insert mode (matches the main nvim config).
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
      vim.keymap.set({ "i", "c" }, "<C-j>", "<Plug>(skkeleton-toggle)")
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
-- On startup, open the scratch buffer at the end and drop into insert mode.
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local scratch = vim.fn.expand(SCRATCH_FILE)
    if vim.fn.filereadable(scratch) == 0 then
      vim.fn.writefile({}, scratch)
    end
    vim.cmd("edit " .. vim.fn.fnameescape(scratch))
    vim.cmd("normal! G")
    vim.schedule(function() vim.cmd("startinsert!") end)
  end,
})

-- Once skkeleton finishes loading via denops, auto-enable it so the user
-- doesn't have to press <C-j> every time the window appears.
vim.api.nvim_create_autocmd("User", {
  pattern = "DenopsPluginPost:skkeleton",
  callback = function()
    vim.schedule(function()
      if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i" then
        vim.cmd("startinsert!")
      end
      local keys = vim.api.nvim_replace_termcodes("<Plug>(skkeleton-enable)",
        true, false, true)
      vim.api.nvim_feedkeys(keys, "i", false)
    end)
  end,
})

-- -----------------------------------------------------------------------------
-- Commit: yank current line / selection (without trailing newline) and let
-- Hammerspoon switch focus and paste into the previous iTerm2 window.
--
-- Workflow: type Japanese in insert mode, <Esc> to normal, <CR> to commit.
-- -----------------------------------------------------------------------------
local function commit_to_hammerspoon()
  vim.fn.jobstart({ "open", "-g", COMMIT_URL }, { detach = true })
end

vim.keymap.set("n", "<CR>", function()
  vim.fn.setreg("+", vim.api.nvim_get_current_line())
  commit_to_hammerspoon()
end, { desc = "Commit current line to previous app" })

vim.keymap.set("v", "<CR>", function()
  vim.cmd('normal! "+y')
  vim.fn.setreg("+", (vim.fn.getreg("+"):gsub("\n$", "")))
  commit_to_hammerspoon()
end, { desc = "Commit selection to previous app" })

-- -----------------------------------------------------------------------------
-- Auto-save the scratch buffer so the always-on session never has unsaved
-- changes to complain about on quit.
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "FocusLost" }, {
  callback = function()
    if vim.bo.modified and vim.bo.buftype == "" and vim.fn.expand("%") ~= "" then
      vim.cmd("silent! write")
    end
  end,
})
