#!/bin/bash
export PATH="$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

LOCK="/tmp/matugen-theme.lock"

if [ -f "$LOCK" ]; then
  exit 0
fi

touch "$LOCK"
trap 'rm -f "$LOCK"' EXIT

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/waypaper/config.ini"

wallpaper=$(awk -F '=' '/^\s*wallpaper\s*=/{print $2; exit}' "$CONFIG" | xargs)
wallpaper="${wallpaper/#\~/$HOME}"

if [ -z "$wallpaper" ] || [ ! -f "$wallpaper" ]; then
  exit 1
fi

matugen image "$wallpaper" --source-color-index 0

# hyprctl reload

kitty @ set-colors -a ~/.config/kitty/theme.conf 2>/dev/null || true

pkill swaync
swaync &
