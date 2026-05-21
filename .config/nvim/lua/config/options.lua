-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
--
-- If no prettier config file is found, the formatter will not be used
vim.g.lazyvim_prettier_needs_config = true

local opt = vim.opt
opt.scrolloff = 999
opt.virtualedit = "all"
-- opt.fillchars = "eob: "
