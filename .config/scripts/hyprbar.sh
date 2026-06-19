#!/usr/bin/env fish

# Detecta o WM atual
set wm $XDG_SESSION_DESKTOP

# Caminho da config do Hyprland
set HYPR_CONFIG $HOME/.config/waybar/

# Só roda se estiver no Hyprland
if test $wm = "Hyprland"
    echo "Rodando Waybar com config do Hyprland 💖"
    waybar -c $HYPR_CONFIG/config -s $HYPR_CONFIG/style.css &
end
