local Input = require("lib.input")

local M = {}

---@param config? wrapinput.Config
function M.setup(config)
	vim.ui.input = function(opts, on_confirm)
		local input = Input:new(config or {}, opts or {}, on_confirm)
		input:open(opts.default or "")
	end
end

return M
