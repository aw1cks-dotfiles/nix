-- lazyvim-nix #115 uses owner--repo dev paths; direct Nix package paths also
-- differ from plugin.name. lazy.nvim 11.17.5's basename lookup misses both,
-- skipping require-triggered runtimepath registration and configuration.
-- Patch during spec discovery, before startup/plugin initialization.
-- Remove when lazy.nvim resolves ownership by configured directory itself.
local Config = require("lazy.core.config")
require("lazy.core.plugin").find = function(path, opts)
	if not Config.spec then
		return
	end
	local lua = path:find("/lua/", 1, true)
	if not lua then
		return
	end
	local directory = path:sub(1, lua - 1)
	local plugins = opts and opts.fast and Config.spec.meta.plugins or Config.spec.plugins
	for _, plugin in pairs(plugins) do
		if plugin.dir == directory then
			return plugin
		end
	end
end

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
