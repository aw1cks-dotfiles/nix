return {
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				nixd = {
					-- Without settings, client.settings.nixd is an empty Lua table,
					-- which nvim serialises as `[]`. nixd requires an object and logs
					-- "workspace/configuration: parse error expected object" on every
					-- config request, silently dropping formatting config.
					settings = {
						nixd = {
							formatting = {
								command = { "nixfmt" },
							},
						},
					},
				},
			},
		},
	},
}
