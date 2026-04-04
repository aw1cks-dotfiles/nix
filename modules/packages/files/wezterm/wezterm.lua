local wezterm = require("wezterm")
local settings = require("settings")

local config = wezterm.config_builder()
config:set_strict_mode(true)

require("appearance").apply(config, settings)
require("binds").apply(config, settings)

return config
