return {
  {
    "folke/lazy.nvim",
    opts = {},
    config = function()
      -- Neovim options
      vim.opt.relativenumber = false
      vim.opt.number = true

      -- Disable asyncomplete completely
      vim.g.asyncomplete_auto_popup = 0
      vim.g.asyncomplete_tab_enable = 0

      -- Disable built-in completion menu if it appears
      vim.opt.completeopt = "menu,menuone,noselect"

      -- Clipboard settings
      vim.opt.clipboard = "unnamedplus"

      -- Disable <C-c> in insert / cmdline modes so it stops standing in
      -- for <Esc>. Without this, Vim's default makes <C-c> behave like a
      -- weak Esc; mapping to <Nop> forces actual <Esc> (or <C-[>) usage.
      vim.keymap.set('i', '<C-c>', '<Nop>', { noremap = true })
      vim.keymap.set('c', '<C-c>', '<Nop>', { noremap = true })
    end,
    priority = 1000,
    lazy = false,
  },
}
