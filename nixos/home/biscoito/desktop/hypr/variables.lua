-- =========================================================
--____  _               _ _
-- |  _ \(_)             (_) |
-- | |_) |_| ___  ___ ___  _| |_ ___
-- |  _  | |/ __|/ __/ _ \| | __/ _ \
-- | |_) | |\__ \ (__ (_) | | |_ (_) |
-- |____/|_|____/\___\___/|_|\__\___/
-- Hyprland config - Lua Version
--
-- VARIAVEIS --
local M = {}

M.left = "h"
M.down = "j"
M.up = "k"
M.right = "l"

M.mod = "SUPER"

M.term = "kitty"
-- M.menu = "~/.config/rofi/runner.sh"
M.menu = "qs -c phone ipc call phone toggle"
M.color = "hyprpicker -a"
M.editor = "kitty nvim"
M.files = "nautilus"

M.screenshot = [[
grim - | tee ~/Imagens/Screenshots/scrn-$(date +"%Y-%m-%d-%H-%M-%S").png | wl-copy
]]

M.printArea = [[
grim -g "$(slurp)" - | tee ~/Imagens/Screenshots/scrn-$(date +"%Y-%m-%d-%H-%M-%S").png | wl-copy
]]

hl.env("GTK_ICON_THEME", "Papirus")
hl.env("QS_ICON_THEME", "Papirus")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

return M
