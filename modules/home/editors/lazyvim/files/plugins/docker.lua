return {
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				docker_compose_language_service = {
					filetypes = { "yaml.docker-compose" },
				},
			},
		},
	},
	{
		"LazyVim/LazyVim",
		init = function()
			vim.filetype.add({
				filename = {
					["docker-compose.yml"] = "yaml.docker-compose",
					["docker-compose.yaml"] = "yaml.docker-compose",
					["compose.yml"] = "yaml.docker-compose",
					["compose.yaml"] = "yaml.docker-compose",
				},
			})
		end,
	},
}
