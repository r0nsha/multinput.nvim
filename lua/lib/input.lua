local utils = require("lib.utils")
local defaults = require("lib.config").defaults

---@class multinput.Input
---@field config multinput.Config
---@field winnr integer
---@field bufnr integer
---@field on_confirm fun(input?: string)
local Input = {}

local group = vim.api.nvim_create_augroup("multinput.nvim", { clear = true })

---@param config multinput.Config
---@param opts any
---@param on_confirm fun(input?: string)
function Input:new(config, opts, on_confirm)
  local i = {}
  i.config = vim.tbl_deep_extend("force", defaults, config, { win = { title = opts.prompt or "Input: " } })
  i.default = opts.default or ""
  i.on_confirm = on_confirm or function() end
  setmetatable(i, self)
  self.__index = self
  return i
end

---@param default string
function Input:open(default)
  -- Position window relative to the cursor, such that it doesn't overlap with the cursor's line.
  local curr_win = vim.api.nvim_get_current_win()
  local cursor_row = vim.api.nvim_win_get_cursor(curr_win)[1]
  local win_config = (cursor_row <= 3) and { anchor = "NW", row = 1 } or { anchor = "SW", row = 0 }
  self.config = vim.tbl_deep_extend("keep", self.config, { win = win_config })

  -- Create buffer and floating window.
  self.bufnr = vim.api.nvim_create_buf(false, true)
  utils.set_options({ buftype = "prompt", bufhidden = "wipe" }, { buf = self.bufnr })
  vim.fn.prompt_setprompt(self.bufnr, "")

  self.winnr = vim.api.nvim_open_win(self.bufnr, true, self.config.win)
  utils.set_options({ wrap = true, linebreak = true, winhighlight = "Search:None" }, { win = self.winnr })

  -- Write default value and put cursor at the end
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, { default })
  vim.cmd("startinsert")
  vim.api.nvim_win_set_cursor(self.winnr, { 1, vim.str_utfindex(default, "utf-8") + 1 })

  self:resize()
  self:autocmds()
  self:mappings()
end

---@param result string?
function Input:close(result)
  vim.cmd("stopinsert")
  vim.api.nvim_win_close(self.winnr, true)
  self.on_confirm(result)
end

---@param height integer
---@return boolean
function Input:set_numbers(height)
  if self.config.opts.numbers == "always" or (self.config.opts.numbers == "multiline" and height > 1) then
    utils.set_option_if_globally_enabled("number", self.winnr)
    utils.set_option_if_globally_enabled("relativenumber", self.winnr)
  end

  return vim.api.nvim_get_option_value("number", { win = self.winnr })
    or vim.api.nvim_get_option_value("relativenumber", { win = self.winnr })
end

---@param width integer
---@param height integer
function Input:set_size(width, height)
  local h = utils.clamp(height, self.config.height.min, self.config.height.max)
  vim.api.nvim_win_set_height(self.winnr, h)

  local w = utils.clamp(width + self.config.padding, self.config.width.min, self.config.width.max)

  local has_numbers = self:set_numbers(h)
  w = has_numbers and w + utils.get_linenr_width(self.winnr, self.bufnr) or w
  w = w + 2 -- HACK: add padding to avoid glitches
  vim.api.nvim_win_set_width(self.winnr, w)
end

function Input:resize()
  local text = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
  local line = table.concat(text, "")

  if line == "" then
    self:set_size(0, 1)
    return
  end

  local lines = utils.split_wrapped_lines(line, self.config.width.max)

  local lens = vim.tbl_map(function(l)
    return vim.fn.strdisplaywidth(l)
  end, lines)

  self:set_size(math.max(unpack(lens)), #lines)
end

function Input:autocmds()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    buffer = self.bufnr,
    callback = function()
      self:resize()
    end,
  })
end

function Input:mappings()
  ---@param mode string|string[]
  ---@param lhs string
  ---@param rhs string|function
  local function map(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = self.bufnr })
  end

  map({ "n", "i", "v" }, "<cr>", function()
    self:close(vim.api.nvim_buf_get_lines(self.bufnr, 0, 1, false)[1])
  end)
  map({ "i" }, "<a-cr>", function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<cr>", true, false, true), "n", true)
  end)

  map("n", "<esc>", function()
    self:close()
  end)

  map("n", "q", function()
    self:close()
  end)
end

return Input
