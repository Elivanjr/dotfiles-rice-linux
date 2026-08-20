-- =========================================================
--____  _               _ _
-- |  _ \(_)             (_) |
-- | |_) |_| ___  ___ ___  _| |_ ___
-- |  _  | |/ __|/ __/ _ \| | __/ _ \
-- | |_) | |\__ \ (__ (_) | | |_ (_) |
-- |____/|_|____/\___\___/|_|\__\___/
-- Hyprland config - Lua Version
--
-- ANIMATIONS --

-- Curva
hl.curve("myEase", {
	type = "bezier",
	points = {
		{ 0.23, 1 },
		{ 0.32, 1 },
	},
})

-- Windows In
hl.animation({
	leaf = "windowsIn",
	enabled = true,
	speed = 5,
	bezier = "myEase",
	style = "slide",
})

-- Windows Out
hl.animation({
	leaf = "windowsOut",
	enabled = true,
	speed = 5,
	bezier = "myEase",
	style = "slide",
})
