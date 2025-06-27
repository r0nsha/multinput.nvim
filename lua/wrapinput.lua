---@class wrapinput.Config
---@field width wrapinput.Limits
---@field height wrapinput.Limits
---@field padding integer
---@field win vim.api.keyset.win_config

---@class wrapinput.Limits
---@field min integer
---@field max integer

local group = vim.api.nvim_create_augroup("wrapinput.nvim", { clear = true })

---@type wrapinput.Config
local defaults = {
	padding = 5,
	width = { min = 20, max = 60 },
	height = { min = 1, max = 6 },
	win = {
		title = "Input: ",
		style = "minimal",
		focusable = true,
		relative = "cursor",
		col = -1,
		height = 1,
	},
}

---@param value number
---@param min number
---@param max number
---@return number
local function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

---@return vim.api.keyset.win_config
local function get_relative_win_config()
	local curr_win = vim.api.nvim_get_current_win()
	local cursor_row = vim.api.nvim_win_get_cursor(curr_win)[1]
	if cursor_row <= 3 then
		return { anchor = "NW", row = 1 }
	else
		return { anchor = "SW", row = 0 }
	end
end

---@param text string
---@param width integer
---@return string[]
local function split_wrapped_lines(text, width)
	if text == "" then
		return {}
	end

	---@type string[]
	local lines = {}
	local textlen = vim.fn.strchars(text, true)

	local i = 0
	while i < textlen do
		local len = i + width <= textlen and width or textlen - i
		local new_line = vim.fn.strcharpart(text, i, len)

		table.insert(lines, new_line)
		i = i + len
	end

	return lines
end

---@param option string
---@param winnr integer
local function set_option_if_globally_enabled(option, winnr)
	if vim.api.nvim_get_option_value(option, { scope = "global" }) then
		vim.api.nvim_set_option_value(option, true, { win = winnr })
	end
end

---@param winnr integer
---@param bufnr integer
---@param config wrapinput.Config
local function resize(winnr, bufnr, config)
	local text = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local line = table.concat(text, "")

	if line == "" then
		vim.api.nvim_win_set_width(winnr, clamp(config.padding, config.width.min, config.width.max))
		vim.api.nvim_win_set_height(winnr, 1)
		return
	end

	local lines = split_wrapped_lines(line, config.width.max)

	local lens = vim.tbl_map(function(l)
		return vim.fn.strdisplaywidth(l)
	end, lines)
	local width = clamp(math.max(unpack(lens)) + config.padding + #lines, config.width.min, config.width.max + #lines)
	vim.api.nvim_win_set_width(winnr, width)

	local height = clamp(#lines, config.height.min, config.height.max)
	vim.api.nvim_win_set_height(winnr, height)

	if height > 1 then
		set_option_if_globally_enabled("number", winnr)
		set_option_if_globally_enabled("relativenumber", winnr)
	end
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

local M = {}

---@param config wrapinput.Config
---@param opts table
---@param on_confirm fun(input: string?)
function M.input(config, opts, on_confirm)
	config = vim.tbl_deep_extend("force", defaults, config, { win = { title = opts.prompt } })
	local default = opts.default or ""
	on_confirm = on_confirm or function() end

	local width = clamp(vim.fn.strdisplaywidth(default) + config.padding, config.width.min, config.width.max)
	vim.notify("width: " .. tostring(width))
	config = vim.tbl_deep_extend("keep", config, { win = get_relative_win_config() }, { win = { width = width } })

	-- Create buffer and floating window.
	local bufnr = vim.api.nvim_create_buf(false, true)
	set_options({ buftype = "prompt", bufhidden = "wipe", textwidth = config.width.max }, { buf = bufnr })
	vim.fn.prompt_setprompt(bufnr, "")

	local winnr = vim.api.nvim_open_win(bufnr, true, config.win)
	set_options({ wrap = true, linebreak = true, winhighlight = "Search:None" }, { win = winnr })

	-- write default value and put cursor at the end
	vim.api.nvim_buf_set_text(bufnr, 0, 0, 0, 0, { default })
	vim.cmd("startinsert")
	vim.api.nvim_win_set_cursor(winnr, { 1, vim.str_utfindex(default, "utf-8") + 1 })

	resize(winnr, bufnr, config)

	setup_mappings(winnr, bufnr, on_confirm)
	setup_autocmds(winnr, bufnr, config)
end

---@param config? wrapinput.Config
function M.setup(config)
	vim.ui.input = function(opts, on_confirm)
		M.input(config or {}, opts or {}, on_confirm)
	end
end

return M
