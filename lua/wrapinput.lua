---@class wrapinput.UserConfig
---@field padding? integer
---@field max_width? integer
---@field max_height? integer
---@field win? vim.api.keyset.win_config

---@class wrapinput.Config
---@field prompt string
---@field default string
---@field padding integer
---@field max_width integer
---@field max_height integer
---@field win vim.api.keyset.win_config

local group = vim.api.nvim_create_augroup("wrapinput.nvim", { clear = true })
local default_prompt = "Input: "

local M = {}

---@type wrapinput.Config
local defaults = {
	prompt = default_prompt,
	default = "",
	padding = 20,
	max_width = 50,
	max_height = 8,
	win = {
		title = default_prompt,
		style = "minimal",
		focusable = true,
		relative = "cursor",
		col = -1,
		height = 1,
	},
}

---@return vim.api.keyset.win_config
local function get_relative_win_config()
	local curr_win = vim.api.nvim_get_current_win()
	local cursor_row = vim.api.nvim_win_get_cursor(curr_win)[1]
	if cursor_row == 1 then
		return { anchor = "NW", row = 1 }
	else
		return { anchor = "SW", row = 0 }
	end
end

---@param text string
---@param width integer
---@return string[]
local function guesstimate_wrapped_lines(text, width)
	local breakat = vim.o.breakat
	local linebreak = vim.wo.linebreak
	local showbreak = vim.o.showbreak
	local showbreak_width = vim.fn.strdisplaywidth(showbreak)

	local result = {}
	local current_line = ""
	local current_width = 0
	local last_break_idx = nil

	local i = 1
	while i <= #text do
		local char = text:sub(i, i)

		local char_width = vim.fn.strdisplaywidth(char)

		-- Track legal break point
		if breakat:find(vim.pesc(char), 1, true) then
			last_break_idx = #current_line + 1
		end

		-- If this char would overflow screen width
		if current_width + char_width > width then
			if linebreak and last_break_idx then
				table.insert(result, current_line:sub(1, last_break_idx))
				i = i - (#current_line - last_break_idx)
			elseif last_break_idx then
				table.insert(result, current_line:sub(1, last_break_idx))
				i = i - (#current_line - last_break_idx)
			else
				table.insert(result, current_line)
			end

			-- Reset for wrapped line
			current_line = showbreak
			current_width = showbreak_width
			last_break_idx = nil
		else
			current_line = current_line .. char
			current_width = current_width + char_width
			i = i + 1
		end
	end

	if #current_line > 0 then
		table.insert(result, current_line)
	end

	return result
end

---@param winnr integer
---@param bufnr integer
---@param config wrapinput.Config
local function resize(winnr, bufnr, config)
	local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]

	if line == "" then
		vim.api.nvim_win_set_width(winnr, config.padding)
		vim.api.nvim_win_set_height(winnr, 1)
		return
	end

	local lines = guesstimate_wrapped_lines(line, config.max_width)

	-- set width
	local lens = vim.tbl_map(function(l)
		return vim.fn.strdisplaywidth(l)
	end, lines)
	local width = math.max(unpack(lens)) + config.padding
	width = width > config.max_width and config.max_width or width
	vim.api.nvim_win_set_width(winnr, width + 1)

	-- set height
	local height = #lines
	height = height > config.max_height and config.max_height or height
	vim.api.nvim_win_set_height(winnr, height)
end

---@param winnr integer
---@param bufnr integer
---@param config wrapinput.Config
local function setup_autocmds(winnr, bufnr, config)
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		buffer = bufnr,
		callback = function()
			resize(winnr, bufnr, config)
		end,
	})
end

---@param options table<string, any>
---@param opts vim.api.keyset.option
local function set_options(options, opts)
	for k, v in pairs(options) do
		vim.api.nvim_set_option_value(k, v, opts)
	end
end

---@param winnr integer
---@param bufnr integer
---@param on_confirm fun(input?: string)
local function setup_mappings(winnr, bufnr, on_confirm)
	---@param result string?
	local function close(result)
		vim.cmd("stopinsert")
		vim.api.nvim_win_close(winnr, true)
		on_confirm(result)
	end

	---@param mode string|string[]
	---@param lhs string
	---@param rhs string|function
	local function map(mode, lhs, rhs)
		vim.keymap.set(mode, lhs, rhs, { buffer = bufnr })
	end

	map({ "n", "i", "v" }, "<cr>", function()
		close(vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1])
	end)
	map("n", "<esc>", close)
	map("n", "q", close)
end

---@param config wrapinput.Config
---@param on_confirm fun(input: string?)
function M.input(config, on_confirm)
	config = vim.tbl_deep_extend("force", defaults, config, { win = { title = config.prompt } })
	on_confirm = on_confirm or function() end

	config = vim.tbl_deep_extend(
		"keep",
		config,
		{ win = get_relative_win_config() },
		{ win = { width = vim.fn.strdisplaywidth(config.default) + config.padding } }
	)

	-- Create buffer and floating window.
	local bufnr = vim.api.nvim_create_buf(false, true)
	set_options({ buftype = "prompt", bufhidden = "wipe", textwidth = config.max_width }, { buf = bufnr })
	vim.fn.prompt_setprompt(bufnr, "")

	local winnr = vim.api.nvim_open_win(bufnr, true, config.win)
	set_options({ wrap = true, linebreak = true, winhighlight = "Search:None" }, { win = winnr })

	-- write default value and put cursor at the end
	vim.api.nvim_buf_set_text(bufnr, 0, 0, 0, 0, { config.default })
	vim.cmd("startinsert")
	vim.api.nvim_win_set_cursor(winnr, { 1, vim.str_utfindex(config.default, "utf-8") + 1 })

	resize(winnr, bufnr, config)

	setup_mappings(winnr, bufnr, on_confirm)
	setup_autocmds(winnr, bufnr, config)
end

---@param config? wrapinput.UserConfig
function M.setup(config)
	vim.ui.input = function(opts, on_confirm)
		config = vim.tbl_deep_extend("force", config or {}, opts or {})
		M.input(config --[[@as wrapinput.Config]], on_confirm)
	end
end

return M
