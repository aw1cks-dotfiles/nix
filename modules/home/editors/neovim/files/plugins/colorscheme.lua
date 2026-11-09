return {
	{
		"nyoom-engineering/oxocarbon.nvim",
		init = function()
			-- Upstream oxocarbon.nvim (fnl/oxocarbon/init.fnl) assigns terminal_color_1..15
			-- to non-ANSI base slots (e.g. red 1/9 -> #33b1ff blue, green 2/10 -> #be95ff
			-- purple, yellow 3/11 -> #42be65 green), which scrambles CLI output inside
			-- :terminal buffers. Override with standard ANSI slot semantics on load.
			vim.api.nvim_create_autocmd("ColorScheme", {
				pattern = "oxocarbon",
				callback = function()
					local ansi = {
						[0] = "#262626",
						[1] = "#ee5396",
						[2] = "#42be65",
						[3] = "#ffe97b",
						[4] = "#78a9ff",
						[5] = "#be95ff",
						[6] = "#3ddbd9",
						[7] = "#dde1e6",
						[8] = "#525252",
						[9] = "#ee5396",
						[10] = "#42be65",
						[11] = "#ffe97b",
						[12] = "#78a9ff",
						[13] = "#be95ff",
						[14] = "#3ddbd9",
						[15] = "#ffffff",
					}
					for idx, hex in pairs(ansi) do
						vim.g["terminal_color_" .. idx] = hex
					end
				end,
			})
		end,
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "oxocarbon",
		},
	},
}
