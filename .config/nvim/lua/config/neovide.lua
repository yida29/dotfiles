-- Loaded only when running under neovide (see lua/config/options.lua).
-- Anything that depends on the GUI (font, <D-…> keymaps, window opts) goes here.

vim.o.guifont = "JetBrainsMonoNL Nerd Font Mono:h14"

vim.keymap.set("n", "<D-s>", ":w<CR>")
vim.keymap.set("v", "<D-c>", '"+y')
vim.keymap.set("n", "<D-v>", '"+P')
vim.keymap.set("v", "<D-v>", '"+P')
vim.keymap.set("c", "<D-v>", "<C-R>+")
vim.keymap.set("i", "<D-v>", '<ESC>l"+Pli')
