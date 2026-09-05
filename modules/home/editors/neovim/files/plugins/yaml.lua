return {
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				yamlls = {
					settings = {
						yaml = {
							customTags = {
								"!reference sequence",
								"!unsafe scalar",
							},
						},
					},
				},
			},
		},
	},
}
