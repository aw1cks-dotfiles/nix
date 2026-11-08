local wezterm = require("wezterm")
local settings = require("settings")

local config = wezterm.config_builder()
config:set_strict_mode(true)

require("appearance").apply(config, settings)
require("binds").apply(config, settings)

-- Extension point for a downstream configuration.
--
-- If `wezterm/user.lua` exists on the Lua module path it is applied to `config`
-- here: after the shared appearance and bindings, before the config is
-- returned. It receives `(config, settings)`, so a consumer can add key
-- bindings or override settings without forking this file.
--
-- Existence is resolved first with `package.searchpath`, so an *absent* module
-- stays silent (the hook is optional) while a module that exists but fails to
-- load — syntax error, missing dependency, error thrown from its body — is
-- reported. A single `pcall` around `require` cannot tell those apart, which
-- would make a broken user.lua indistinguishable from no user.lua at all: the
-- shared config would load with the consumer's overrides quietly missing.
--
-- The `apply` call is deliberately *not* wrapped, for the same reason. If the
-- hook itself raises, wezterm should surface it rather than silently continue.
local module_name = "user"
local module_path = package.searchpath(module_name, package.path)

if module_path ~= nil then
	local loaded, user = pcall(require, module_name)

	if not loaded then
		wezterm.log_error(
			string.format(
				"wezterm: %s exists but failed to load, so its overrides are NOT applied: %s",
				module_path,
				tostring(user)
			)
		)
	elseif type(user) ~= "table" or type(user.apply) ~= "function" then
		wezterm.log_error(
			string.format(
				"wezterm: %s must return a table with an apply(config, settings) function, so its overrides are NOT applied",
				module_path
			)
		)
	else
		user.apply(config, settings)
	end
end

return config
