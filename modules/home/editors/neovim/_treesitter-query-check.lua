local site = assert(arg[1], "usage: nvim -l treesitter-query-check.lua <site>")
vim.opt.runtimepath:prepend(site)

local checked, failures = 0, {}
for file in vim.fs.dir(site .. "/parser") do
	local lang = file:match("^(.+)%.so$")
	if lang then
		local query_dir = site .. "/queries/" .. lang
		local ok, added, err = pcall(vim.treesitter.language.add, lang)
		if not (ok and added) then
			failures[#failures + 1] = ("%s: parser failed to load: %s"):format(lang, tostring(ok and err or added))
		elseif vim.uv.fs_stat(query_dir) then
			for query_file in vim.fs.dir(query_dir) do
				local query = query_file:match("^(.+)%.scm$")
				if query then
					checked = checked + 1
					local qok, qerr = pcall(vim.treesitter.query.get, lang, query)
					if not qok then
						failures[#failures + 1] = ("%s/%s: %s"):format(lang, query, (tostring(qerr):gsub("%s+", " ")))
					end
				end
			end
		end
	end
end

if #failures > 0 then
	io.stderr:write("Treesitter parser/query mismatch:\n  " .. table.concat(failures, "\n  ") .. "\n")
	io.stderr:write("Keep the nvim-treesitter plugin, parsers, and queries aligned to the same source snapshot.\n")
	os.exit(1)
end
print(("treesitter: %d queries parse against their parsers"):format(checked))
