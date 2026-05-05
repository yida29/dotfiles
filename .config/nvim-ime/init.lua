-- =============================================================================
-- nvim-ime: Minimal Neovim config for Japanese input via skkeleton
-- Launch with: NVIM_APPNAME=nvim-ime nvim
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Bootstrap lazy.nvim
-- -----------------------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- -----------------------------------------------------------------------------
-- Minimal UI
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

-- -----------------------------------------------------------------------------
-- Plugins
-- -----------------------------------------------------------------------------
require("lazy").setup({
  { "vim-denops/denops.vim", lazy = false },
  {
    "vim-skk/skkeleton",
    dependencies = { "vim-denops/denops.vim" },
    config = function()
      vim.keymap.set("i", "<C-j>", "<Plug>(skkeleton-toggle)")
      vim.keymap.set("c", "<C-j>", "<Plug>(skkeleton-toggle)")
      vim.api.nvim_create_autocmd("User", {
        pattern = "skkeleton-initialize-pre",
        callback = function()
          vim.fn["skkeleton#config"]({
            globalDictionaries = { { "~/.skk/SKK-JISYO.L", "euc-jp" } },
          })
        end,
      })
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function()
      return {
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "filename" },
          lualine_c = {},
          lualine_x = {
            {
              cond = function()
                return vim.fn["skkeleton#is_enabled"]()
              end,
              function()
                return vim.fn["skkeleton#mode"]()
              end,
              color = { fg = "#ff9e64", gui = "bold" },
            },
          },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      }
    end,
  },
})

-- -----------------------------------------------------------------------------
-- Auto-enter insert mode and enable skkeleton on startup
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local scratch = vim.fn.expand("~/Documents/ime-scratch.md")
    if vim.fn.filereadable(scratch) == 0 then
      vim.fn.writefile({}, scratch)
    end
    vim.cmd("edit " .. vim.fn.fnameescape(scratch))
    vim.cmd("normal! G")
    vim.schedule(function()
      vim.cmd("startinsert!")
    end)
  end,
})

-- Auto-press <C-j> after skkeleton is loaded (feed via <Plug> mapping)
vim.api.nvim_create_autocmd("User", {
  pattern = "DenopsPluginPost:skkeleton",
  callback = function()
    vim.schedule(function()
      if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i" then
        vim.cmd("startinsert!")
      end
      local keys = vim.api.nvim_replace_termcodes("<Plug>(skkeleton-enable)", true, false, true)
      vim.api.nvim_feedkeys(keys, "i", false)
    end)
  end,
})

-- -----------------------------------------------------------------------------
-- Convenience keymaps for IME use
-- -----------------------------------------------------------------------------
vim.keymap.set("n", "<Space>y", 'ggVG"+y', { desc = "Yank all to clipboard" })
vim.keymap.set("n", "<Space>d", "ggVGd", { desc = "Delete all" })
vim.keymap.set("n", "<Space><CR>", 'ggVG"+ygg"_dG', { desc = "Yank all then clear" })

-- -----------------------------------------------------------------------------
-- Commit input: yank current line / selection to clipboard, then ask
-- Hammerspoon to switch focus back and paste it into the previous app.
-- -----------------------------------------------------------------------------
local function commit_to_hammerspoon()
  vim.fn.jobstart({ "open", "-g", "hammerspoon://nvim-ime-commit" }, { detach = true })
end

vim.keymap.set("n", "<D-CR>", function()
  vim.cmd('normal! "+yy')
  commit_to_hammerspoon()
end, { desc = "Commit current line to previous app" })

vim.keymap.set("v", "<D-CR>", function()
  vim.cmd('normal! "+y')
  commit_to_hammerspoon()
end, { desc = "Commit selection to previous app" })

vim.keymap.set("i", "<D-CR>", function()
  vim.cmd("stopinsert")
  vim.schedule(function()
    vim.cmd('normal! "+yy')
    commit_to_hammerspoon()
  end)
end, { desc = "Commit current line to previous app (from insert)" })

-- -----------------------------------------------------------------------------
-- Auto-save scratch buffer
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "FocusLost" }, {
  pattern = "*",
  callback = function()
    if vim.bo.modified and vim.bo.buftype == "" and vim.fn.expand("%") ~= "" then
      vim.cmd("silent! write")
    end
  end,
})
