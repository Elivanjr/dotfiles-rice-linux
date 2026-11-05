-- =========================================================
--____  _               _ _
-- |  _ \(_)             (_) |
-- | |_) |_| ___  ___ ___  _| |_ ___
-- |  _  | |/ __|/ __/ _ \| | __/ _ \
-- | |_) | |\__ \ (__ (_) | | |_ (_) |
-- |____/|_|____/\___\___/|_|\__\___/
-- Hyprland config - Lua Version

-- Propriedades de Janelas --
--Eden
hl.window_rule({
	match = { class = "^(eden)$" },
	center = true,
	opacity = 1,
})

-- Blueman
hl.window_rule({
	match = { class = "^(blueman-manager)$" },
	float = true,
	center = true,
	size = "800 600",
	opacity = 1,
})

hl.window_rule({
	match = { class = "^(blueman-sendto)$" },
	float = true,
	center = true,
	size = "800 600",
	opacity = 1,
})

-- Hyprland Share Picker (escolher tela pra OBS/DISCORD/etc)
hl.window_rule({
	match = { class = "^(hyprland-share-picker)$" },
	float = true,
	center = true,
	size = "800 600",
	opacity = 1,
})

-- NetworkManager
hl.window_rule({
	match = { class = "^(nm-connection-editor)$" },
	float = true,
	center = true,
	size = "800 600",
})

-- MPV
hl.window_rule({
	match = { class = "^(mpv)$" },
	float = true,
	center = true,
	size = "1024 576",
})

-- VLC
hl.window_rule({
	match = { class = "^(vlc)$" },
	float = true,
	center = true,
	size = "1024 576",
	max_size = "1024 576",
})

-- SongRec
hl.window_rule({
	match = { class = "^(re.fossplant.songrec)$" },
	float = true,
	center = true,
	size = "1050 600",
})

-- Waypaper
hl.window_rule({
	match = { class = "^(waypaper)$" },
	float = true,
	center = true,
})

-- PulseAudio Volume Control
hl.window_rule({
	match = { class = "^(org.pulseaudio.pavucontrol)$" },
	float = true,
})

hl.window_rule({
	match = { class = "^(pavucontrol)$" },
	center = true,
	size = "800 600",
})

-- nwg-look
hl.window_rule({
	match = { class = "^(nwg-look)$" },
	float = true,
})

-- Ark
hl.window_rule({
	match = { class = "^(org.kde.ark)$" },
	float = true,
})

-- qView
hl.window_rule({
	match = { class = "^(com.interversehq.qView)$" },
	float = true,
	center = true,
	size = "1080 620",
})

-- Imagens
hl.window_rule({
	match = { class = "^(file-png)$" },
	float = true,
})

hl.window_rule({
	match = { class = "^(file-jpeg)$" },
	float = true,
})

-- Dolphin Emulator
hl.window_rule({
	match = { class = "^(dolphin-emu)$" },
	float = true,
})

-- Gifview
hl.window_rule({
	match = { class = "^(org.kde.gwenview)$" },
	float = true,
	center = true,
	opacity = 1,
})

-- XDG Desktop Portal
hl.window_rule({
	match = { class = "^(Xdg-desktop-portal-gtk)$" },
	float = true,
	center = true,
	opacity = 1,
})

-- GNOME Terminal
hl.window_rule({
	match = { class = "^(org.gnome.Terminal)" },
	float = true,
	center = true,
})

-- Steam game
hl.window_rule({
	match = { class = "^(steam_app_0)$" },
	float = true,
	center = true,
})

-- Steam
hl.window_rule({
	match = { class = "^(steam)$" },
	center = true,
})

-- Explorer.exe
hl.window_rule({
	match = { class = "^(explorer.exe)$" },
	float = true,
	center = true,
})

-- Discord
hl.window_rule({
	match = { class = "^(discord)$" },
	center = true,
})

-- APP X vai abrir no Workspace Y, tipo o Brave sempre vai abrir no workspace 2 --
-- Code
hl.window_rule({
	match = { class = "^(codium)$" },
	workspace = 1,
})

hl.window_rule({
	match = { title = "^(VSCodium)$" },
	workspace = 1,
})

-- Browser
hl.window_rule({
	match = { class = "^(brave-browser)$" },
	workspace = 2,
})

hl.window_rule({
	match = { class = "^(brave-origin)$" },
	workspace = 2,
})

-- Discord
hl.window_rule({
	match = { class = "^(discord)$" },
	workspace = 5,
})

-- IA — ChatGPT + Claude
hl.window_rule({
	match = {
		class = "^(brave-cadlkienfkclaiaibeoongdcgmdikeeg-Default)$",
	},
	workspace = 3,
})

hl.window_rule({
	match = {
		class = "^(brave-fmpnliohjhemenmnlpbfagaolkdacoja-Default)$",
	},
	workspace = 3,
})

-- Dolphin
hl.window_rule({
	match = { class = "^(org.gnome.Nautilus)$" },
	workspace = 8,
})

hl.window_rule({
	match = {
		class = "^(gimp)$",
	},
	workspace = 12,
})

-- Spotify
hl.window_rule({
	match = { class = "^(Spotify)$" },
	workspace = 4,
})

-- YouTube
hl.window_rule({
	match = {
		class = "^(brave-agimnkijcaahngcdmfeangaknmldooml-Default)$",
	},
	workspace = 6,
})

-- X (Twitter)
hl.window_rule({
	match = {
		class = "^(brave-lodlkdfmihgonocnmddehnfgiljnadcf-Default)$",
	},
	workspace = 7,
})

-- Instagram
hl.window_rule({
	match = {
		class = "^(brave-akpamiohjfcnimfljfndmaldlcfphjmp-Default)$",
	},
	workspace = 2,
})

-- WhatsApp
hl.window_rule({
	match = {
		class = "^(brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default)$",
	},
	workspace = 10,
})

-- Steam, Heroic
hl.window_rule({
	match = { class = "^(steam)$" },
	workspace = 9,
})
hl.window_rule({
	match = { class = "^(steam_app_0)$" },
	workspace = 10,
})
hl.window_rule({
	match = { class = "^(com.heroicgameslauncher.hgl)$" },
	workspace = 9,
})

hl.window_rule({
	match = {
		class = "^(kopuz)$",
	},
	workspace = 4,
})

hl.window_rule({
	match = {
		class = "^(ai.storyteller.photocraft)$",
	},
	workspace = 12,
})

hl.window_rule({
	match = {
		class = "^(ai.storyteller.filmcraft)$",
	},
	workspace = 11,
})

hl.window_rule({
	match = {
		class = "^(ai.storyteller.artcraft-launcher)$",
	},
	workspace = 12,
})
-- Opacidade --

hl.window_rule({
	match = { class = "^(discord)$" },
	opacity = 0.88,
})

hl.window_rule({
	match = { class = "^(codium)$" },
	opacity = 0.88,
})

hl.window_rule({
	match = { class = "^(Spotify)$" },
	opacity = 0.87,
})

hl.window_rule({
	match = { class = "^(org.kde.dolphin)$" },
	opacity = 1,
})

--hl.window_rule({
--	match = { class = "^(brave-origin)$" },
--	opacity = 0.87,
--})

hl.window_rule({
	match = { class = "^(brave-lodlkdfmihgonocnmddehnfgiljnadcf-Default)$" },
	opacity = 1,
})

hl.window_rule({
	match = { class = "^(Xdg-desktop-portal-gtk)$" },
	border_size = 0,
})

hl.window_rule({
	match = { title = "Selecionar arquivo|Salvar como|Abrir arquivo" },
	border_size = 0,
})
