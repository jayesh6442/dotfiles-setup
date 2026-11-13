-- Keymaps ported from the previous NvChad config (NvChad v2.5 defaults + custom).
-- NvChad-only targets are remapped to the equivalents available here:
--   Telescope    -> Snacks.picker
--   nvim-tree    -> Snacks.explorer (opens on the right, like before)
--   nvchad.term  -> Snacks.terminal
--   tabufline    -> :bnext / :bprev / Snacks.bufdelete
--   which-key / NvCheatsheet -> Snacks.picker.keymaps
local map = vim.keymap.set

local function S()
	return require("snacks")
end

-- insert-mode movement
map("i", "<C-b>", "<ESC>^i", { desc = "move beginning of line" })
map("i", "<C-e>", "<End>", { desc = "move end of line" })
map("i", "<C-h>", "<Left>", { desc = "move left" })
map("i", "<C-l>", "<Right>", { desc = "move right" })
map("i", "<C-j>", "<Down>", { desc = "move down" })
map("i", "<C-k>", "<Up>", { desc = "move up" })

-- windows: same keys as before, but at the edge of nvim they continue into the
-- neighbouring tmux pane (pairs with ~/.config/tmux/bindings.conf)
local function nav(dir)
	return function()
		local win = vim.api.nvim_get_current_win()
		vim.cmd.wincmd(dir)
		if vim.env.TMUX and win == vim.api.nvim_get_current_win() then
			local flag = ({ h = "-L", j = "-D", k = "-U", l = "-R" })[dir]
			vim.fn.system({ "tmux", "select-pane", flag })
		end
	end
end
map("n", "<C-h>", nav("h"), { desc = "switch window left" })
map("n", "<C-l>", nav("l"), { desc = "switch window right" })
map("n", "<C-j>", nav("j"), { desc = "switch window down" })
map("n", "<C-k>", nav("k"), { desc = "switch window up" })

-- ===== AI agent (tmux pane) =====
-- Find the agent pane (claude/codex/opencode/gemini) in the current tmux window
local function agent_pane()
	if not vim.env.TMUX then
		vim.notify("Not inside tmux", vim.log.levels.WARN)
		return nil
	end
	local out = vim.fn.systemlist({ "tmux", "list-panes", "-F", "#{pane_id} #{pane_current_command}" })
	local me = vim.env.TMUX_PANE
	for _, line in ipairs(out) do
		local id, cmd = line:match("^(%S+) (%S+)")
		if id ~= me and cmd and vim.tbl_contains({ "claude", "codex", "opencode", "gemini", "node" }, cmd) then
			return id
		end
	end
	vim.notify("No agent pane in this tmux window (tmux prefix + a opens one)", vim.log.levels.WARN)
end

-- Send "@path" (or "@path#L10-20" for a selection) to the agent and focus it
local function send_to_agent(with_range)
	local pane = agent_pane()
	if not pane then
		return
	end
	local ref = "@" .. vim.fn.expand("%:.")
	if with_range then
		local s, e = vim.fn.line("v"), vim.fn.line(".")
		if s > e then
			s, e = e, s
		end
		ref = ref .. "#L" .. s .. (e ~= s and ("-" .. e) or "")
		vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
	end
	vim.fn.system({ "tmux", "send-keys", "-t", pane, "-l", ref .. " " })
	vim.fn.system({ "tmux", "select-pane", "-t", pane })
end

map("n", "<leader>aa", function()
	local pane = agent_pane()
	if pane then
		vim.fn.system({ "tmux", "select-pane", "-t", pane })
	end
end, { desc = "AI: jump to agent pane" })
map("n", "<leader>as", function() send_to_agent(false) end, { desc = "AI: send file to agent" })
map("x", "<leader>as", function() send_to_agent(true) end, { desc = "AI: send selection lines to agent" })

map("n", "<Esc>", "<cmd>noh<CR>", { desc = "general clear highlights" })

map("n", "<C-s>", "<cmd>w<CR>", { desc = "general save file" })
map("n", "<C-c>", "<cmd>%y+<CR>", { desc = "general copy whole file" })

map("n", "<leader>n", "<cmd>set nu!<CR>", { desc = "toggle line number" })
map("n", "<leader>ch", function()
	S().picker.keymaps()
end, { desc = "keymap cheatsheet" })

map({ "n", "x" }, "<leader>fm", function()
	require("conform").format({ lsp_fallback = true })
end, { desc = "general format file" })

map("n", "<leader>ds", vim.diagnostic.setloclist, { desc = "LSP diagnostic loclist" })

-- buffers (was tabufline)
map("n", "<leader>b", "<cmd>enew<CR>", { desc = "buffer new" })
map("n", "<tab>", "<cmd>bnext<CR>", { desc = "buffer goto next" })
map("n", "<S-tab>", "<cmd>bprev<CR>", { desc = "buffer goto prev" })
map("n", "<leader>x", function()
	S().bufdelete()
end, { desc = "buffer close" })

-- comment
map("n", "<leader>/", "gcc", { desc = "toggle comment", remap = true })
map("v", "<leader>/", "gc", { desc = "toggle comment", remap = true })

-- file tree (was nvim-tree, right side)
local function explorer()
	return S().explorer({ layout = { layout = { position = "right", width = 30 } } })
end
map("n", "<C-n>", explorer, { desc = "file tree toggle" })
map("n", "<leader>e", function()
	local pickers = S().picker.get({ source = "explorer" })
	if pickers[1] then
		pickers[1]:focus()
	else
		explorer()
	end
end, { desc = "file tree focus" })

-- pickers (was telescope)
map("n", "<leader>fw", function() S().picker.grep() end, { desc = "live grep" })
map("n", "<leader>fb", function() S().picker.buffers() end, { desc = "find buffers" })
map("n", "<leader>fh", function() S().picker.help() end, { desc = "help page" })
map("n", "<leader>ma", function() S().picker.marks() end, { desc = "find marks" })
map("n", "<leader>fo", function() S().picker.recent() end, { desc = "find oldfiles" })
map("n", "<leader>fz", function() S().picker.lines() end, { desc = "find in current buffer" })
map("n", "<leader>cm", function() S().picker.git_log() end, { desc = "git commits" })
map("n", "<leader>gt", function() S().picker.git_status() end, { desc = "git status" })
map("n", "<leader>th", function() S().picker.colorschemes() end, { desc = "themes" })
map("n", "<leader>ff", function() S().picker.files() end, { desc = "find files" })
map("n", "<leader>fa", function()
	S().picker.files({ hidden = true, ignored = true, follow = true })
end, { desc = "find all files" })

-- terminal
map("t", "<C-x>", "<C-\\><C-N>", { desc = "terminal escape terminal mode" })

local term_n = 100
local function new_term(position)
	term_n = term_n + 1
	S().terminal.open(nil, { count = term_n, win = { position = position } })
end
map("n", "<leader>h", function() new_term("bottom") end, { desc = "terminal new horizontal term" })
map("n", "<leader>v", function() new_term("right") end, { desc = "terminal new vertical term" })

map({ "n", "t" }, "<A-v>", function()
	S().terminal.toggle(nil, { count = 1, win = { position = "right" } })
end, { desc = "terminal toggleable vertical term" })
map({ "n", "t" }, "<A-h>", function()
	S().terminal.toggle(nil, { count = 2, win = { position = "bottom" } })
end, { desc = "terminal toggleable horizontal term" })
map({ "n", "t" }, "<A-i>", function()
	S().terminal.toggle(nil, { count = 3, win = { position = "float", border = "rounded" } })
end, { desc = "terminal toggle floating term" })

-- keymap lookup (was which-key)
map("n", "<leader>wK", function() S().picker.keymaps() end, { desc = "all keymaps" })
map("n", "<leader>wk", function()
	S().picker.keymaps({ pattern = vim.fn.input("Keymap: ") })
end, { desc = "keymap query lookup" })

-- ===== custom (from old lua/mappings.lua) =====
map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("n", "gr", vim.lsp.buf.references, { desc = "LSP references" })
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "LSP rename" })
map("n", "<leader>f", function()
	vim.lsp.buf.format({ async = true })
end, { desc = "LSP format file" })

-- ===== NvChad LspAttach buffer mappings =====
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local function opts(desc)
			return { buffer = args.buf, desc = "LSP " .. desc }
		end
		map("n", "gD", vim.lsp.buf.declaration, opts("Go to declaration"))
		map("n", "gd", vim.lsp.buf.definition, opts("Go to definition"))
		map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, opts("Add workspace folder"))
		map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, opts("Remove workspace folder"))
		map("n", "<leader>wl", function()
			print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
		end, opts("List workspace folders"))
		map("n", "<leader>D", vim.lsp.buf.type_definition, opts("Go to type definition"))
		map("n", "<leader>ra", vim.lsp.buf.rename, opts("Rename"))
	end,
})
