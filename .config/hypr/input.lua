-- =========================================================
--____  _               _ _
-- |  _ \(_)             (_) |
-- | |_) |_| ___  ___ ___  _| |_ ___
-- |  _  | |/ __|/ __/ _ \| | __/ _ \
-- | |_) | |\__ \ (__ (_) | | |_ (_) |
-- |____/|_|____/\___\___/|_|\__\___/
-- Hyprland config - Lua Version
--
-- INPUT --
hl.config({
	input = {
		kb_layout = "br",
		kb_variant = "abnt2",
		kb_model = "",
		kb_options = "",
		kb_rules = "",

		follow_mouse = 1,

		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
		},
	},
})

hl.device({
	name = "usb-keyboard-usb-keyboard",

	kb_layout = "br",
	kb_variant = "abnt2",
})
