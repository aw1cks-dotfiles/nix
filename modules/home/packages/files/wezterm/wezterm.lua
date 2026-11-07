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
-- The hook is optional, so a host without `user.lua` is unaffected. A `user.lua`
-- that exists but fails to load, or that does not expose an
-- `apply(config, settings)` function, is reported through `wezterm.log_error`
-- instead of failing the whole configuration silently.
local has_user, user = pcall(require, "user")
if has_user then
	if type(user) == "table" and type(user.apply) == "function" then
		user.apply(config, settings)
	else
		wezterm.log_error("wezterm user.lua must return a table with an apply(config, settings) function")
	end
end

return config
