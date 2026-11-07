return {
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				kotlin_language_server = {
					-- lspconfig sets storagePath to the project root, so Kotlin LS writes
					-- kls_database.db into every repository. Outside a Gradle/Maven project
					-- the value is nil, nvim sends initializationOptions = [] and Kotlin LS
					-- fails its Gson decode ("Expected BEGIN_OBJECT but was BEGIN_ARRAY").
					-- Keep one cache per project root under stdpath("cache") instead, so
					-- repositories stay clean and projects never share a cache database.
					before_init = function(params, config)
						local root = config.root_dir or vim.fn.getcwd()
						local dir = vim.fs.joinpath(
							vim.fn.stdpath("cache"),
							"kotlin-language-server",
							vim.fn.sha256(root):sub(1, 16)
						)
						vim.fn.mkdir(dir, "p")
						params.initializationOptions =
							vim.tbl_extend("force", params.initializationOptions or {}, { storagePath = dir })
					end,
				},
			},
		},
	},
}
