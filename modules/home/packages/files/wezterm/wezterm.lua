local wezterm = require("wezterm")
local settings = require("settings")

-- Home Manager wraps native extraConfig in `extend`, preserving both direct
-- config mutations and returned-table overrides without replacing this layer.
return function(extend, initial_config)
	local config = wezterm.config_builder()
	config:set_strict_mode(true)

	require("appearance").apply(config, settings)
	require("binds").apply(config, settings)

	-- Native Home Manager settings override shared defaults before extraConfig.
	for key, value in pairs(initial_config or {}) do
		config[key] = value
	end

	local extra = extend(config)
	if type(extra) == "table" then
		for key, value in pairs(extra) do
			config[key] = value
		end
	end

	-- The optional downstream hook runs last, after shared and native config.
	-- Resolve existence separately: missing is silent, but syntax, dependency,
	-- shape and apply errors must fail configuration rather than drop overrides.
	local module_name = "user"
	local module_path = package.searchpath(module_name, package.path)

	if module_path ~= nil then
		local user = require(module_name)
		assert(
			type(user) == "table" and type(user.apply) == "function",
			string.format("wezterm: %s must return a table with an apply(config, settings) function", module_path)
		)
		user.apply(config, settings)
	end

	return config
end
