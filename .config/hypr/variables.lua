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

M.mod = "SUPER"

M.left = "h"
M.down = "j"
M.up = "k"
M.right = "l"

M.term = "kitty"
M.menu = "~/.config/rofi/runner.sh"
M.color = "hyprpicker -a"
M.editor = "kitty nvim"
M.files = "dolphin"

M.screenshot = [[
grim - | tee ~/Imagens/Screenshots/scrn-$(date +"%Y-%m-%d-%H-%M-%S").png | wl-copy
]]

M.printArea = [[
grim -g "$(slurp)" - | tee ~/Imagens/Screenshots/scrn-$(date +"%Y-%m-%d-%H-%M-%S").png | wl-copy
]]

return M
