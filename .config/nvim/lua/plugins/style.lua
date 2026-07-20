return {
	{
		"nvim-lualine/lualine.nvim",
		opts = function(_, opts)
			-- Mode/section colors use tokyonight (lualine's default "auto" theme).
			local ok, tn = pcall(require, "tokyonight.colors")
			local colors = ok and tn.setup() or {}
			local state_color = {
				clean = colors.green or "#9ece6a",
				staged = colors.orange or "#ff9e64",
				unstaged = colors.red or "#f7768e",
			}

			-- Branch color reflects git state: clean=green, staged=orange,
			-- unstaged=red (unstaged wins if both). Computed async via
			-- `git status --porcelain` and cached per buffer so redraws never
			-- block on git; recomputed on the events below.
			-- One git call at a time, debounced, redraw only on real change.
			-- Otherwise a buffer-churning stage (neogit/fugitive opening buffers)
			-- fires a storm of BufEnter events that each spawn git + redraw and
			-- can lock up the UI.
			local git_running = false
			local git_pending = false
			local git_timer
			local function compute_git_state()
				if git_running then
					git_pending = true -- coalesce; re-run once the current call finishes
					return
				end
				local buf = vim.api.nvim_get_current_buf()
				local dir = vim.bo[buf].buftype == "" and vim.fn.expand("%:p:h") or ""
				if dir == "" then
					dir = vim.fn.getcwd()
				end
				git_running = true
				vim.system({ "git", "-C", dir, "status", "--porcelain" }, { text = true }, function(res)
					local state = "clean"
					if res.code == 0 and res.stdout then
						for line in res.stdout:gmatch("[^\n]+") do
							local x, y = line:sub(1, 1), line:sub(2, 2)
							if x == "?" or y ~= " " then
								state = "unstaged" -- untracked or working-tree change
								break
							elseif x ~= " " then
								state = "staged" -- index change, keep scanning for unstaged
							end
						end
					end
					vim.schedule(function()
						git_running = false
						if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].branch_git_state ~= state then
							vim.b[buf].branch_git_state = state
							vim.cmd("redrawstatus")
						end
						if git_pending then -- an event arrived mid-flight; recompute once
							git_pending = false
							compute_git_state()
						end
					end)
				end)
			end
			local function update_git_state()
				if git_timer then
					git_timer:stop()
				end
				git_timer = vim.defer_fn(compute_git_state, 150)
			end
			vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FocusGained", "ShellCmdPost", "CursorHold" }, {
				group = vim.api.nvim_create_augroup("lualine_branch_git_state", { clear = true }),
				callback = update_git_state,
			})
			vim.schedule(update_git_state)

			-- Square dividers, no powerline arrows.
			opts.options.section_separators = ""
			opts.options.component_separators = "│"

			-- Minimal layout.
			opts.sections = {
				lualine_a = { "mode" },
				lualine_b = {
					{
						"branch",
						color = function()
							local state = vim.b.branch_git_state or "clean"
							return { fg = state_color[state], bg = "NONE", gui = "bold" }
						end,
					},
				},
				lualine_c = {
					{ "diagnostics" },
					{
						-- Shorten each directory to one char but always keep the
						-- full filename, e.g. lua/plugins/style.lua -> l/p/style.lua
						function()
							local path = vim.fn.expand("%:~:.")
							if path == "" then
								return "[No Name]"
							end
							path = vim.fn.pathshorten(path)
							if vim.bo.modified then
								path = path .. " [+]"
							end
							return path
						end,
					},
				},
				lualine_x = {
					{
						"diff",
						-- Retro ASCII git symbols instead of nerd-font glyphs.
						symbols = { added = "+", modified = "±", removed = "-" },
						source = function()
							local gs = vim.b.gitsigns_status_dict
							if gs then
								return { added = gs.added, modified = gs.changed, removed = gs.removed }
							end
						end,
					},
				},
				lualine_y = {},
				lualine_z = {},
			}
		end,
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
			on_highlights = function(hl, c)
				-- Subtle full-width cursorline that fits the moon palette.
				-- bg_highlight (#2f334d) is the theme's own line-highlight color;
				-- against the transparent terminal bg it reads as a faint bar.
				hl.CursorLine = { bg = c.bg_highlight }
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
