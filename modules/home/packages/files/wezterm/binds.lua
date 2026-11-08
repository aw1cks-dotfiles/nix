local wezterm = require("wezterm")

local function modifier(platform)
	if platform == "linux" then
		-- SUPER interferes with tiling WM modifier
		return "ALT"
	end

	return "SUPER"
end

local M = {}

function M.apply(config, settings)
	local pane_increment = 5

	local primary_modifier = modifier(settings.platform)
	local secondary_modifier = primary_modifier .. "|SHIFT"
	config.keys = {
		{
			key = "phys:LeftBracket",
			mods = primary_modifier,
			action = wezterm.action({
				SplitHorizontal = { domain = "CurrentPaneDomain" },
			}),
		},
		{
			key = "phys:RightBracket",
			mods = primary_modifier,
			action = wezterm.action({
				SplitVertical = { domain = "CurrentPaneDomain" },
			}),
		},
		{
			key = "LeftArrow",
			mods = primary_modifier,
			action = wezterm.action({
				ActivatePaneDirection = "Left",
			}),
		},
		{
			key = "RightArrow",
			mods = primary_modifier,
			action = wezterm.action({
				ActivatePaneDirection = "Right",
			}),
		},
		{
			key = "UpArrow",
			mods = primary_modifier,
			action = wezterm.action({
				ActivatePaneDirection = "Up",
			}),
		},
		{
			key = "DownArrow",
			mods = primary_modifier,
			action = wezterm.action({
				ActivatePaneDirection = "Down",
			}),
		},
		{
			key = "LeftArrow",
			mods = secondary_modifier,
			action = wezterm.action({
				AdjustPaneSize = { "Left", pane_increment },
			}),
		},
		{
			key = "RightArrow",
			mods = secondary_modifier,
			action = wezterm.action({
				AdjustPaneSize = { "Right", pane_increment },
			}),
		},
		{
			key = "UpArrow",
			mods = secondary_modifier,
			action = wezterm.action({
				AdjustPaneSize = { "Up", pane_increment },
			}),
		},
		{
			key = "DownArrow",
			mods = secondary_modifier,
			action = wezterm.action({
				AdjustPaneSize = { "Down", pane_increment },
			}),
		},
		{
			key = "phys:T",
			mods = secondary_modifier,
			action = wezterm.action({
				SpawnTab = "CurrentPaneDomain",
			}),
		},
		{
			key = "b",
			mods = "OPT",
			action = wezterm.action({
				SendKey = { key = "b", mods = "ALT" },
			}),
		},
		{
			key = "d",
			mods = "OPT",
			action = wezterm.action({
				SendKey = { key = "d", mods = "ALT" },
			}),
		},
		{
			key = "f",
			mods = "OPT",
			action = wezterm.action({
				SendKey = { key = "f", mods = "ALT" },
			}),
		},
		{
			key = "s",
			mods = "OPT",
			action = wezterm.action({
				SendKey = { key = "s", mods = "ALT" },
			}),
		},
	}

	-- Bind positions, not US shifted symbols: gb produces " / £ for Shift+2 / 3.
	-- Preserve WezTerm's convention that 9 selects the last tab.
	for i = 1, 9 do
		local action = wezterm.action.ActivateTab(i == 9 and -1 or i - 1)
		table.insert(config.keys, {
			key = "phys:" .. tostring(i),
			mods = "CTRL|SHIFT",
			action = action,
		})

		if settings.platform == "darwin" then
			table.insert(config.keys, {
				key = "phys:" .. tostring(i),
				mods = "SUPER",
				action = action,
			})
		end
	end
end

return M
