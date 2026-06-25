#!/bin/bash

WALL=$(find ~/Imagens/hyprlandWallpapers -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) |
  shuf -n 1)

ln -sf "$WALL" ~/.cache/lockscreen-wallpaper

exec hyprlock
