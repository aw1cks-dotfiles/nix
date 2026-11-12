return {
	{
		"neovim/nvim-lspconfig",
		opts = function(_, opts)
			opts.servers.ansiblels.cmd = function(dispatchers, config)
				local root = config.root_dir or config.cmd_cwd or vim.uv.cwd()
				local cmd = { "ansible-language-server", "--stdio" }
				if vim.fs.find(".envrc", { path = root, upward = true, type = "file", limit = 1 })[1] then
					-- Let direnv enforce trust; never replace a blocked/broken project env.
					cmd = { opts.ansible_direnv, "exec", root, "ansible-language-server", "--stdio" }
				end
				return vim.lsp.rpc.start(cmd, dispatchers, {
					cwd = config.cmd_cwd or root,
					env = config.cmd_env,
					detached = config.detached,
				})
			end
		end,
	},
}
