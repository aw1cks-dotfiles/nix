return {
	{
		"folke/lazy.nvim",
		init = function()
			local ok, config = pcall(require, "lazy.core.config")
			if ok then
				config.options.rocks.enabled = false
				config.options.rocks.hererocks = false
			end
		end,
	},
}
