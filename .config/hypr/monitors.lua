-- =========================================================
--____  _               _ _
-- |  _ \(_)             (_) |
-- | |_) |_| ___  ___ ___  _| |_ ___
-- |  _  | |/ __|/ __/ _ \| | __/ _ \
-- | |_) | |\__ \ (__ (_) | | |_ (_) |
-- |____/|_|____/\___\___/|_|\__\___/
-- Hyprland config - Lua Version
--
-- MONITORS --
local modo = "espelhar"
-- local modo = "unir"

-- MEU NOTEBOOK
hl.monitor({
	output = "eDP-1",
	mode = "1366x768@60.05900",
	position = "0x0",
	scale = 1,
})

if modo == "espelhar" then
	hl.monitor({
		output = "HDMI-A-1",
		mode = "1366x768@60.00400",
		position = "0x0", -- espelhar tela
		scale = 1,
		mirror = "eDP-1", -- informa o monitor a ser espelhar
	})

	--hl.monitor({ --monitor extra de um amigo
	--  output = "<saida>",
	--  mode = "<modo>",
	--  position = "0x0",
	--  scale = 1,
	--  mirror = "eDP-1"
	--})
end

if modo == "unir" then
	hl.monitor({
		output = "HDMI-A-1",
		mode = "1366x768@60.00400",
		position = "1366x0", -- unir tela
		scale = 1,
	})

	--hl.monitor({ --monitor extra de um amigo
	--  output = "<saida>",
	--  mode = "<modo>",
	--  position = "1366x0", -- extender tela
	--  scale = 1,
	--})
end
