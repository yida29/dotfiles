-- Disable Snacks' bundled file explorer so it doesn't appear alongside
-- neo-tree. With Snacks v3 the `explorer` module is on by default, which
-- (combined with LazyVim's default <leader>e binding pointed at Snacks)
-- means pressing <leader>e opens "Explorer 76/76" as a picker beside the
-- neo-tree pane we already have.
--
-- Turning the module off below ALSO has the side effect of unbinding
-- the <leader>e / <leader>fe / <leader>E / <leader>fE mappings that
-- snacks_explorer.lua wires up; LazyVim's neo-tree spec rebinds them
-- to neo-tree as long as snacks isn't claiming them first.

return {
  {
    "folke/snacks.nvim",
    opts = {
      explorer = { enabled = false },
      picker = {
        sources = {
          explorer = { enabled = false },
        },
      },
    },
    keys = {
      -- Make sure <leader>e / <leader>fe land on neo-tree, not Snacks.
      { "<leader>e",  "<cmd>Neotree toggle reveal<cr>",       desc = "Explorer (root dir)" },
      { "<leader>E",  "<cmd>Neotree toggle reveal dir=.<cr>", desc = "Explorer (cwd)" },
      { "<leader>fe", "<cmd>Neotree toggle reveal<cr>",       desc = "Explorer (root dir)" },
      { "<leader>fE", "<cmd>Neotree toggle reveal dir=.<cr>", desc = "Explorer (cwd)" },
    },
  },
}
