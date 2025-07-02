local M = {}

---@param options table<string, any>
---@param opts vim.api.keyset.option
function M.set_options(options, opts)
  for k, v in pairs(options) do
    vim.api.nvim_set_option_value(k, v, opts)
  end
end

---@param option string
---@param winnr integer
function M.set_option_if_globally_enabled(option, winnr)
  if vim.api.nvim_get_option_value(option, { scope = "global" }) then
    vim.api.nvim_set_option_value(option, true, { win = winnr })
  end
end

---@param value number
---@param min number
---@param max number
---@return number
function M.clamp(value, min, max)
  return math.min(math.max(value, min), max)
end

---@param text string
---@param width integer
---@return string[]
function M.split_wrapped_lines(text, width)
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

---@param winnr integer
---@param bufnr integer
---@return integer
function M.get_linenr_width(winnr, bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local line_digits = math.floor(math.log10(math.max(1, line_count))) + 1
  local numberwidth = vim.api.nvim_get_option_value("numberwidth", { win = winnr })
  return math.max(line_digits, numberwidth)
end

return M
