return {
	-- Upstream discovery can retain the original from the pre-switch HOME.
	{ "sindrets/diffview.nvim", enabled = false },
	{
		"dlyongemallo/diffview-plus.nvim",
		main = "diffview",
		opts = {
			view = {
				merge_tool = {
					layout = "diff3_mixed",
				},
			},
		},
	},
	{
		"lewis6991/gitsigns.nvim",
		keys = {
			{
				"<leader>ug",
				"<cmd>Gitsigns toggle_signs<cr>",
				desc = "Toggle Git Signs",
			},
			{
				"<leader>ul",
				function()
					-- Reuse LazyVim's toggle so off/on restores the number modes.
					Snacks.toggle.get("line_number"):toggle()
					vim.cmd("Gitsigns toggle_signs")
				end,
				desc = "Toggle Line Numbers",
			},
		},
	},
}
