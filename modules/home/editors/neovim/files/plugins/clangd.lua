return {
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				clangd = {
					-- No --compile-commands-dir: clangd searches parent directories and
					-- build/ on its own, and pinning the flag would block a repository's
					-- .clangd CompilationDatabase: redirect.
					cmd = {
						"clangd",
						"--enable-config",
						"--pch-storage=memory",
						"--header-insertion=never",
						"-j",
						tostring(
							(vim.uv.available_parallelism and vim.uv.available_parallelism())
								or tonumber(vim.fn.systemlist("nproc")[1])
								or 1
						),
					},
					-- "build" as a bare directory name resolves the root to the project
					-- root; the nested path "build/compile_commands.json" would resolve
					-- the root to build/ itself.
					root_markers = { "compile_commands.json", ".clangd", "build", ".git" },
				},
			},
		},
	},
}
