local colors = require("colors")
-- =========================================================
--____  _               _ _
-- |  _ \(_)             (_) |
-- | |_) |_| ___  ___ ___  _| |_ ___
-- |  _  | |/ __|/ __/ _ \| | __/ _ \
-- | |_) | |\__ \ (__ (_) | | |_ (_) |
-- |____/|_|____/\___\___/|_|\__\___/
-- Hyprland config - Lua Version
--
-- DECORATION --
hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 10,
		border_size = 2,
		layout = "dwindle",

		col = {
			active_border = colors.active_border,
			inactive_border = colors.inactive_border,
		},
	},

	decoration = {
		rounding = 10,

		blur = {
			enabled = false,
		},

		active_opacity = 1.0,
		inactive_opacity = 1.0,
		fullscreen_opacity = 1.0,
	},
})
