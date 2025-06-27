---@class multinput.Config
---@field opts multinput.Opts
---@field width multinput.Limits
---@field height multinput.Limits
---@field padding integer How much padding will be added to the end of the input buffer
---@field win vim.api.keyset.win_config

---@class multinput.Opts
---@field numbers "always" | "multiline" | "never" When to show line numbers
--- "always" will always show line numbers
--- "multiline" will only show line numbers if the input's height is > 1
--- "never" will never show line numbers

---@class multinput.Limits
---@field min integer
---@field max integer

return {
    ---@type multinput.Config
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
            width = 1,
            height = 1,
        },
    },
}
