local wezterm = require("wezterm")

local function background(config, settings)
  config.window_background_opacity = settings.window.background_opacity

  if settings.window.macos_background_blur then
    config.macos_window_background_blur = settings.window.macos_background_blur
  end

  if settings.window.native_macos_fullscreen_mode ~= nil then
    config.native_macos_fullscreen_mode = settings.window.native_macos_fullscreen_mode
  end

  if settings.window.macos_fullscreen_extend_behind_notch ~= nil then
    config.macos_fullscreen_extend_behind_notch = settings.window.macos_fullscreen_extend_behind_notch
  end
end

local function colour_scheme(config, settings)
  config.color_scheme = settings.color_scheme
  config.colors = config.colors or {}
  config.colors.background = "#161616"
end

local function cursor(config, settings)
  config.default_cursor_style = settings.default_cursor_style
  config.cursor_blink_rate = settings.cursor_blink_rate
end

local function font(config, settings)
  local font_faces = {
    { family = settings.font.family, weight = settings.font.weight },
    settings.font.emoji_fallback,
  }
  config.font = wezterm.font_with_fallback(font_faces)
  config.font_size = settings.font.size
end

local function inactive_pane(config, settings)
  config.inactive_pane_hsb = settings.inactive_pane_hsb
end

local function visual_bell(config, _settings)
  config.visual_bell = {
    fade_in_function = "Linear",
    fade_in_duration_ms = 100,
    fade_out_function = "EaseOut",
    fade_out_duration_ms = 100,
  }
  config.colors = config.colors or {}
  config.colors.visual_bell = "#202020"
end

local function window_settings(config, settings)
  config.initial_cols = settings.window.initial_cols
  config.initial_rows = settings.window.initial_rows

  config.tab_max_width = 32
  config.hide_tab_bar_if_only_one_tab = true

  config.window_decorations = settings.window.decorations

  local window_padding = settings.window.padding
  config.window_padding = {
    left = window_padding,
    right = window_padding,
    top = window_padding,
    bottom = window_padding,
  }
end

local M = {}

function M.apply(config, settings)
  background(config, settings)
  colour_scheme(config, settings)
  cursor(config, settings)
  font(config, settings)
  inactive_pane(config, settings)
  window_settings(config, settings)
  visual_bell(config, settings)
end

return M
