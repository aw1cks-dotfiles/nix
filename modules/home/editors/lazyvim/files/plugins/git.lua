local Util = require("lazyvim.util")

return {
	{
		"sindrets/diffview.nvim",
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
					Util.toggle_number()
					vim.cmd("Gitsigns toggle_signs")
				end,
				desc = "Toggle Line Numbers",
			},
		},
	},
}
