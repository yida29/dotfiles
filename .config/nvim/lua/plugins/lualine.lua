return {
	"nvim-lualine/lualine.nvim",
	opts = function(_, opts)
		table.insert(opts.sections.lualine_x, 1, {
			cond = function()
				return vim.fn["skkeleton#is_enabled"]()
			end,
			function()
				return vim.fn["skkeleton#mode"]()
			end,
			color = { fg = "#ff9e64", gui = "bold" },
		})
	end,
}
