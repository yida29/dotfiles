-- Loaded only when running under neovide (see lua/config/options.lua).
-- Anything that depends on the GUI (font, <D-…> keymaps, window opts) goes here.

vim.o.guifont = "JetBrainsMonoNL Nerd Font Mono:h14"

vim.keymap.set("n", "<D-s>", ":w<CR>")
vim.keymap.set("v", "<D-c>", '"+y')

-- <D-v> paste. Modes: "" = normal+visual+operator-pending, "!" = insert
-- and command-line, "t" = terminal, "v" extra so visual gets register +
-- explicitly (the "" mapping pastes after-cursor, which loses selection).
vim.keymap.set("", "<D-v>", "+p<CR>", { noremap = true, silent = true })
vim.keymap.set("!", "<D-v>", "<C-R>+", { noremap = true, silent = true })
vim.keymap.set("t", "<D-v>", "<C-R>+", { noremap = true, silent = true })
vim.keymap.set("v", "<D-v>", "<C-R>+", { noremap = true, silent = true })
