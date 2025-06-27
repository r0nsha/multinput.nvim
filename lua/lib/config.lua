---@class wrapinput.Config
---@field opts wrapinput.Opts
---@field width wrapinput.Limits
---@field height wrapinput.Limits
---@field padding integer How much padding will be added to the end of the input buffer
---@field win vim.api.keyset.win_config

---@class wrapinput.Opts
---@field numbers "always" | "multiline" | "never" When to show line numbers
--- "always" will always show line numbers
--- "multiline" will only show line numbers if the input's height is > 1
--- "never" will never show line numbers

---@class wrapinput.Limits
---@field min integer
---@field max integer

return {
	---@type wrapinput.Config
	defaults = {
		opts = { numbers = "multiline" },
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
	},
}
