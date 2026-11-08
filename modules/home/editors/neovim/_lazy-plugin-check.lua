vim.opt.rtp:prepend(vim.env.LAZY_PLUGIN)
dofile(vim.env.COMPAT_FILE)
require("lazy").setup({
	root = vim.env.HOME .. "/plugins",
	lockfile = vim.env.HOME .. "/lazy-lock.json",
	install = { missing = false },
	checker = { enabled = false },
	change_detection = { enabled = false },
	rocks = { enabled = false },
	spec = {
		{
			"folke/trouble.nvim",
			dir = vim.env.PLUGIN_DIR,
			cmd = "Trouble",
			opts = {},
		},
	},
})

local ok, err = xpcall(function()
	local plugin = require("lazy.core.config").plugins["trouble.nvim"]
	assert(not plugin._.loaded, "Trouble must remain lazy before require")
	local symbols = require("trouble").statusline({ mode = "symbols" })
	assert(plugin._.loaded, "require must activate and configure Trouble")
	assert(type(symbols.get) == "function" and type(symbols.has) == "function", "statusline unavailable")
	assert(require("trouble.config").get("symbols").source == "lsp.document_symbols", "runtime sources not registered")
	assert(require("lazy.core.plugin").find(plugin.dir .. "/lua/trouble/init.lua", { fast = true }) == plugin)
end, debug.traceback)

if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
else
	local result = assert(io.open(vim.env.RESULT_FILE, "w"))
	result:write("require-based plugin activation preserves runtime sources\n")
	result:close()
	vim.cmd("qa!")
end
