-- Loaded only when running under neovide (see lua/config/options.lua).
-- Anything that depends on the GUI (font, <D-…> keymaps, window opts) goes here.

vim.o.guifont = "JetBrainsMonoNL Nerd Font Mono:h14"

vim.keymap.set("n", "<D-s>", ":w<CR>", { desc = "Save" })
vim.keymap.set("v", "<D-c>", '"+y', { desc = "Copy" })

-- <D-v> paste, single-keymap form per neovide FAQ. nvim_paste handles
-- bracketed paste and indent normalization for us, so it works in
-- insert/cmdline/terminal as well as normal/visual without per-mode RHS.
vim.keymap.set({ "n", "i", "v", "c", "t" }, "<D-v>", function()
  vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
end, { silent = true, desc = "Paste" })
