return {
	{
		"neovim/nvim-lspconfig",
		opts = function(_, opts)
			local server = opts.servers.yamlls
			-- Helm owns chart values and their chart-aware schema/completions.
			-- A second YAML client otherwise contributes unrelated resource fields.
			-- TODO: Make values activation chart-root-aware, cover .yml, and preserve YAML outside charts.
			server.filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab" }
			-- Keep SchemaStore at association priority, below explicit schemas.
			-- LazyVim's before_init otherwise flattens both into settings priority.
			server.before_init = nil
			local on_init = server.on_init
			server.on_init = function(client, result)
				if on_init then
					on_init(client, result)
				end
				local associations = require("schemastore").yaml.schemas()
				if opts.yaml_schema_fallback then
					-- This is a fallback, not a schema to combine with catalog schemas.
					-- Use the server's own glob exclusions to leave catalog files alone.
					local fallback = { "*.yaml", "*.yml" }
					local excluded = {}
					for _, patterns in pairs(associations) do
						for _, pattern in ipairs(patterns) do
							if pattern:sub(1, 1) ~= "!" and not excluded[pattern] then
								fallback[#fallback + 1] = "!" .. pattern
								excluded[pattern] = true
							end
						end
					end
					associations[opts.yaml_schema_fallback] = fallback
				end
				client:notify("json/schemaAssociations", associations)
			end
			server.settings.yaml.customTags = vim.list_extend(server.settings.yaml.customTags or {}, {
				"!reference sequence",
				"!unsafe scalar",
			})
		end,
	},
}
