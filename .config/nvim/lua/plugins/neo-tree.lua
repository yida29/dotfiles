return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  opts = {
    filesystem = {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },
    window = {
      position = "left",
      width = 30,
    },
  },
  init = function()
    -- Open Neo-tree on startup, but only when nvim was launched with no
    -- arguments. If the user passed a file or directory, LazyVim / neo-tree
    -- already handles that case (and would otherwise produce a second tree).
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        if vim.fn.argc() == 0 then
          require("neo-tree.command").execute({ action = "show" })
        end
      end,
      desc = "Open Neo-tree on startup when no args are passed",
    })
  end,
}