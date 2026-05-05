return {
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
						globalDictionaries = { "~/.skk/SKK-JISYO.L" },
					})
				end,
			})
		end,
	},
}
