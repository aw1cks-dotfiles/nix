local acp_env = {
	HOME = vim.env.HOME,
}

for _, name in ipairs({
	"XDG_CONFIG_HOME",
	"XDG_DATA_HOME",
	"XDG_CACHE_HOME",
	"XDG_STATE_HOME",
}) do
	local value = vim.env[name]
	if value and value ~= "" then
		acp_env[name] = value
	end
end

return {
	{
		"yetone/avante.nvim",
		event = "VeryLazy",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"stevearc/dressing.nvim",
			"HakonHarnes/img-clip.nvim",
		},
		config = function(_, opts)
			require("avante_lib").load()
			require("avante").setup(opts)

			-- Pinned Avante discards vim.tbl_extend's return value in its provider
			-- picker, so ACP providers are omitted. Remove this after upgrading.
			vim.api.nvim_del_user_command("AvanteSwitchProvider")
			vim.api.nvim_create_user_command("AvanteSwitchProvider", function()
				local config = require("avante.config")
				local providers = vim.tbl_keys(config.providers)
				vim.list_extend(providers, vim.tbl_keys(config.acp_providers))
				table.sort(providers)
				vim.ui.select(providers, { prompt = "Provider> " }, function(choice)
					if choice then
						require("avante.api").switch_provider(vim.trim(choice))
					end
				end)
			end, {
				nargs = 0,
				desc = "avante: switch provider",
			})
		end,
		opts = {
			provider = "omp",
			acp_providers = {
				omp = {
					command = "@omp@",
					args = { "acp", "--config", "@ompAcpConfig@" },
					env = acp_env,
				},
			},
			behaviour = {
				auto_add_current_file = true,
				auto_apply_diff_after_generation = false,
				auto_approve_tool_permissions = false,
				acp_follow_agent_locations = true,
			},
			windows = {
				position = "right",
				width = 38,
			},
		},
	},
}
