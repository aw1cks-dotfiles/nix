vim.opt.guicursor = "a:ver25-blinkon1,i-v:hor20"
vim.opt.clipboard = ""
vim.opt.fixeol = false

vim.g.autoformat = false
vim.g.loaded_node_provider = 0

vim.g.lazyvim_python_lsp = "ty"
vim.g.lazyvim_python_ruff = "ruff"

vim.g.lazyvim_rust_diagnostics = "rust-analyzer"

if vim.g.neovide then
	vim.o.guifont = "CaskaydiaCove NFM:h12"

	vim.g.neovide_padding_top = 32
	vim.g.neovide_padding_bottom = 32
	vim.g.neovide_padding_right = 16
	vim.g.neovide_padding_left = 16

	vim.g.neovide_window_blurred = true
	vim.g.neovide_opacity = 0.95
	vim.g.neovide_normal_opacity = 0.9

	vim.g.neovide_refresh_rate = 165

	vim.g.neovide_position_animation_length = 0.05
	vim.g.neovide_cursor_animation_length = 0.05
	vim.g.neovide_cursor_trail_size = 0
	vim.g.neovide_cursor_animate_in_insert_mode = false
	vim.g.neovide_cursor_animate_command_line = true
	vim.g.neovide_scroll_animation_far_lines = 1
	vim.g.neovide_scroll_animation_length = 0.05
end
