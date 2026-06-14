#!/bin/bash

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/waypaper/config.ini"

wallpaper=$(awk -F '=' '/^\s*wallpaper\s*=/{print $2; exit}' "$CONFIG" | xargs)
wallpaper="${wallpaper/#\~/$HOME}"

if [ -z "$wallpaper" ] || [ ! -f "$wallpaper" ]; then
  echo "Wallpaper inválido: $wallpaper"
  exit 1
fi

wallust run "$wallpaper"

kitty @ set-colors -a ~/.cache/wallust/kitty.conf 2>/dev/null || true
pkill swaync && swaync &
