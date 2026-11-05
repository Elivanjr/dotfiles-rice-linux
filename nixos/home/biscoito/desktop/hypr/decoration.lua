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
		gaps_in = 5, --8
		gaps_out = 10, --10
		border_size = 2,
		--layout = "dwindloe",
		layout = "scrolling",

		col = {
			active_border = colors.active_border,
			inactive_border = colors.inactive_border,
		},
	},

	scrolling = {
		column_width = 1.0,
		focus_fit_method = 0,
		follow_focus = true,
		follow_min_visible = 0.4,
		fullscreen_on_one_column = false,
		explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
		wrap_focus = true,
		wrap_swapcol = true,
		direction = "down",
	},

	decoration = {
		rounding = 10, --8

		blur = {
			enabled = false,
		},

		active_opacity = 1.0,
		inactive_opacity = 1.0,
		fullscreen_opacity = 1.0,
	},
})

hl.layer_rule({
	name = "quickshell-launcher-blur",
	match = { namespace = "quickshell:launcher" },
	blur = true,
	ignore_alpha = 0,
})
