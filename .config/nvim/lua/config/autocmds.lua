-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "typescript", "typescriptreact" },
	callback = function()
		vim.opt_local.shiftwidth = 4
	end,
})

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local idcl = augroup("idcl", { clear = true })
autocmd({ "BufNewFile", "BufReadPost" }, {
	pattern = "*.idcl",
	command = "set filetype=idcl",
	group = idcl,
})

-- local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
-- parser_config.idcl = {
-- 	install_info = {
-- 		url = "~/src/tree-sitter-idcl", -- local path or git repo
-- 		files = { "src/parser.c" }, -- note that some parsers also require src/scanner.c or src/scanner.cc
-- 		-- optional entries:
-- 		branch = "main", -- default branch in case of git repo if different from master
-- 		generate_requires_npm = false, -- if stand-alone parser without npm dependencies
-- 		requires_generate_from_grammar = false, -- if folder contains pre-generated src/parser.c
-- 	},
-- 	filetype = "idcl", -- if filetype does not match the parser name
-- }

-- vim.api.nvim_create_autocmd("ColorScheme", {
--   pattern = "*",
--   callback = function()
--     vim.api.nvim_set_hl(0, )
-- })
