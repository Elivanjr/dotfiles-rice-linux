local M = require("variables")

-- =========================================================
--____  _               _ _
-- |  _ \(_)             (_) |
-- | |_) |_| ___  ___ ___  _| |_ ___
-- |  _  | |/ __|/ __/ _ \| | __/ _ \
-- | |_) | |\__ \ (__ (_) | | |_ (_) |
-- |____/|_|____/\___\___/|_|\__\___/
-- Hyprland config - Lua Version
--
-- ATALHOS --
-- Rofi + Clipboard
hl.bind(M.mod .. " + SHIFT + S", hl.dsp.exec_cmd("~/.config/rofi/clipboard.sh"))

--hl.bind(
--	M.mod .. " + SHIFT + S",
--	hl.dsp.exec_cmd("kitty --class clipse -e clipse", {
--		float = true,
--		size = { 622, 652 },
--		stay_focused = true,
--	})
--)
-- Terminal
hl.bind(M.mod .. " + T", hl.dsp.exec_cmd(M.term))

-- Fechar janela
hl.bind(M.mod .. " + SHIFT + Q", hl.dsp.window.close())

-- Launcher
hl.bind(M.mod .. " + D", hl.dsp.exec_cmd(M.menu))

-- Color picker
hl.bind(M.mod .. " + Z", hl.dsp.exec_cmd(M.color))

-- Editor
hl.bind(M.mod .. " + G", hl.dsp.exec_cmd(M.editor))

-- File Manager
hl.bind(M.mod .. " + E", hl.dsp.exec_cmd(M.files))

-- Waypaper
hl.bind(M.mod .. " + C", hl.dsp.exec_cmd("waypaper"))

-- Waybar
hl.bind(M.mod .. " + O", hl.dsp.exec_cmd("killall -SIGUSR1 waybar"))

-- Swaync
hl.bind(M.mod .. " + M", hl.dsp.exec_cmd("swaync-client -op"))

-- Reload
hl.bind(M.mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"))

-- Sair do Hyprland
hl.bind(M.mod .. " + SHIFT + E", hl.dsp.exit())

-- Screenhot
hl.bind("Print", hl.dsp.exec_cmd(M.screenshot .. " && mpv /usr/share/sounds/freedesktop/stereo/screen-capture.oga"))
hl.bind(
	M.mod .. " + SHIFT + Print",
	hl.dsp.exec_cmd("mpv /usr/share/sounds/freedesktop/stereo/screen-capture.oga && " .. M.printArea)
)

-- Hyprlock (bloqueio de tela)
hl.bind("switch:Lid Switch", hl.dsp.exec_cmd("hyprlock"))

hl.bind(M.mod .. " + L", hl.dsp.exec_cmd('sh -c "pidof hyprlock || hyprlock"'))

-- RESENHA??? isso só serve pra rodar com a mesa de som junto ao audio da resenha... ignore...

hl.bind("SUPER + KP_DOWN", hl.dsp.exec_cmd("pgrep qview && pkill qview || qview ~/Imagens/gif/resenha.gif"))

hl.bind("SUPER + KP_DOWN", hl.dsp.exec_cmd('notify-send -t 13000 -i ~/Imagens/gif/maquina.gif "RESENHA???"'))

-- Mesa de som usando atalhos + mpv

hl.bind(
	M.mod .. " + KP_END",
	hl.dsp.exec_cmd(
		"mpv --no-video --really-quiet yes ~/.config/hypr/scripts/mesaSom/eu-nao-sou-heroi.mp3 >/dev/null 2>&1 &"
	)
)

hl.bind(
	M.mod .. " + KP_DOWN",
	hl.dsp.exec_cmd("mpv --no-video --really-quiet yes ~/.config/hypr/scripts/mesaSom/resenha?.mp4 >/dev/null 2>&1 &")
)

hl.bind(
	M.mod .. " + KP_NEXT",
	hl.dsp.exec_cmd("mpv --no-video --really-quiet yes ~/.config/hypr/scripts/mesaSom/vine.ogg >/dev/null 2>&1 &")
)

hl.bind(
	M.mod .. " + KP_LEFT",
	hl.dsp.exec_cmd("mpv --no-video --really-quiet yes ~/.config/hypr/scripts/mesaSom/faaah.mp3 >/dev/null 2>&1 &")
)

hl.bind("KP_BEGIN", hl.dsp.exec_cmd("~/.config/hypr/scripts/faiz.sh"))

hl.bind(
	M.mod .. " + KP_HOME",
	hl.dsp.exec_cmd("mpv --no-video --really-quiet yes ~/.config/hypr/scripts/mesaSom/auraEgo.mp3 >/dev/null 2>&1 &")
)

hl.bind(
	M.mod .. " + KP_UP",
	hl.dsp.exec_cmd(
		"mpv --no-video --really-quiet yes ~/.config/hypr/scripts/mesaSom/olha-a-mensagem.mp3 >/dev/null 2>&1 &"
	)
)

hl.bind(
	M.mod .. " + KP_PRIOR",
	hl.dsp.exec_cmd(
		"mpv --no-video --really-quiet yes ~/.config/hypr/scripts/mesaSom/brutal-acabou-pro-beta-globo.mp3 >/dev/null 2>&1 &"
	)
)

hl.bind(
	M.mod .. " + KP_DELETE",
	hl.dsp.exec_cmd("mpv --no-video --really-quiet yes ~/.config/hypr/scripts/mesaSom/lonely.mp3 >/dev/null 2>&1 &")
)

hl.bind(
	M.mod .. "+ KP_Subtract",
	hl.dsp.exec_cmd("mpv --no-video --really-quiet yes ~/.config/hypr/scripts/mesaSom/ai.wav >/dev/null 2>&1 &")
)

hl.bind(
	M.mod .. " + KP_ADD",
	hl.dsp.exec_cmd("mpv --no-video --really-quiet yes ~/.config/hypr/scripts/mesaSom/axel2.wav >/dev/null 2>&1 &")
)

hl.bind(
	M.mod .. " + KP_INSERT",
	hl.dsp.exec_cmd("mpv --no-video --really-quiet yes ~/.config/hypr/scripts/mesaSom/faiz_begin.wav >/dev/null 2>&1 &")
)

-- Movimento

hl.bind(M.mod .. " + " .. M.left, hl.dsp.focus({ direction = "left" }))

hl.bind(M.mod .. " + " .. M.right, hl.dsp.focus({ direction = "right" }))

hl.bind(M.mod .. " + " .. M.up, hl.dsp.focus({ direction = "up" }))

hl.bind(M.mod .. " + " .. M.down, hl.dsp.focus({ direction = "down" }))

-- Workspaces
for i = 1, 9 do
	hl.bind(M.mod .. " + " .. i, hl.dsp.focus({ workspace = i }))

	hl.bind(M.mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

hl.bind(M.mod .. " + 0", hl.dsp.focus({ workspace = 10 }))

hl.bind(M.mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))
-- Pior que usar repetição pra criar os workspaces é mt massa

-- Tela cheia e janelas sem tilling

-- hl.bind(M.mod .. " + N", hl.dsp.exec_cmd("hyprctl dispatch fullscreen"))
hl.bind(M.mod .. " + N", hl.dsp.window.fullscreen())

hl.bind(M.mod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))

hl.bind(M.mod .. " + SPACE", hl.dsp.layout("swapwithmaster"))

-- Mouse

hl.bind(M.mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })

-- Volume
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"))

hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd(
		"pactl set-sink-volume @DEFAULT_SINK@ -5% && "
			.. "mpv /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"
	),
	{ locked = true, repeating = true }
)

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd(
		"pactl set-sink-volume @DEFAULT_SINK@ +5% && "
			.. "mpv /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"
	),
	{ locked = true, repeating = true }
)

hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"))

-- Brilho
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 1%-"))

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 1%+"))

-- Workspace secreto, shhh --
hl.bind(M.mod .. " + MINUS", hl.dsp.workspace.toggle_special("magic"))
hl.bind(M.mod .. " + SHIFT + MINUS", hl.dsp.window.move({ workspace = "special:magic" }))

-- Redimensionar janelas, mexendo nesse ainda
-- Entrar no modo resize
hl.bind(M.mod .. " + R", hl.dsp.submap("resize"))

-- Modo resize
hl.define_submap("resize", function()
	-- ← / →
	hl.bind("left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })

	hl.bind("right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }), { repeating = true })

	-- ↑ / ↓
	hl.bind("up", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true })

	hl.bind("down", hl.dsp.window.resize({ x = 0, y = 20, relative = true }), { repeating = true })

	-- ESC = sair do modo resize
	hl.bind("escape", hl.dsp.submap("reset"))
end)
