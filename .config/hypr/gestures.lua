-- =========================================================
--____  _               _ _
-- |  _ \(_)             (_) |
-- | |_) |_| ___  ___ ___  _| |_ ___
-- |  _  | |/ __|/ __/ _ \| | __/ _ \
-- | |_) | |\__ \ (__ (_) | | |_ (_) |
-- |____/|_|____/\___\___/|_|\__\___/
-- Hyprland config - Lua Version
--
-- GESTURES --

-- Navegar pelos workspaces usando gestos de 3 dedos, tipo GNOME
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})
