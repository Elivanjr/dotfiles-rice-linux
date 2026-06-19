#!/bin/bash
clear
MAIN="$HOME/.config/waybar/hyprland/"
ALT="$HOME/.config/waybar/hyprland/other/1"

pkill waybar 2>/dev/null

# swap config
mv "$MAIN/config" "$MAIN/config.tmp"
mv "$ALT/config" "$MAIN/config"
mv "$MAIN/config.tmp" "$ALT/config"

# swap style
mv "$MAIN/style.css" "$MAIN/style.tmp"
mv "$ALT/style.css" "$MAIN/style.css"
mv "$MAIN/style.tmp" "$ALT/style.css"

sleep 0.2
waybar -c "$MAIN/config" -s "$MAIN/style.css" &
sleep 0.5
