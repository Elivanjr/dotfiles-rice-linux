-- =========================================================
--____  _               _ _
-- |  _ \(_)             (_) |
-- | |_) |_| ___  ___ ___  _| |_ ___
-- |  _  | |/ __|/ __/ _ \| | __/ _ \
-- | |_) | |\__ \ (__ (_) | | |_ (_) |
-- |____/|_|____/\___\___/|_|\__\___/
-- Hyprland config - Lua Version
--
-- AUTOSTART --

hl.on("hyprland.start", function()
	hl.exec_cmd("waybar")
	hl.exec_cmd("waypaper --backend awww --restore")
	hl.exec_cmd("swaync")
	hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
	hl.exec_cmd("/usr/bin/kwalletd5")
	hl.exec_cmd("kwalletd6")
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd("libinput-gestures")
	hl.exec_cmd("~/killRust.sh") -- ignore a existencia disso...
	hl.exec_cmd("echo 0 > ~/.cache/faiz/count")
	hl.exec_cmd("~/.config/hypr/scripts/faiz.sh")
	hl.exec_cmd("~/.config/scripts/spotify-notify.sh")
	hl.exec_cmd("mpv /home/bixcoitu/Músicas/mesaSom/faiz_end.wav")
	hl.exec_cmd("brave --password-store=basic")
	hl.exec_cmd("blueman-applet")
end)