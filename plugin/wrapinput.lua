vim.ui.input = function(opts, on_confirm)
	require("wrapinput").input(opts or {}, on_confirm)
end
