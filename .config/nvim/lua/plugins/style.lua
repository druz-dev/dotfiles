return {
	{
		"nvim-lualine/lualine.nvim",
		opts = {
			sections = {
				lualine_y = {
					function()
						return ""
					end,
				},
				lualine_z = {
					function()
						return ""
					end,
				},
			},
		},
	},
	{
		"folke/tokyonight.nvim",
		opts = {
			-- style = "moon",
			style = "moon",
			transparent = true,
			styles = {
				sidebars = "transparent",
				floats = "transparent",
				keywords = { bold = true },
				functions = { bold = true },
			},
			on_colors = function(colors)
				colors.bg_statusline = colors.none -- or colors.none
			end,
		},
	},

	-- Configure LazyVim to load colorscheme
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "tokyonight",
		},
	},

	{
		"akinsho/bufferline.nvim",
	},
	{
		"snacks.nvim",
		opts = {
			dashboard = {
				preset = {
					pick = function(cmd, opts)
						return LazyVim.pick(cmd, opts)()
					end,
					header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝
]],
				},
			},
		},
	},
}
