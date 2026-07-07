#!/bin/bash
COUNT_FILE="$HOME/.cache/faiz/count"

count=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
count=$((count + 1))

echo "$count" >"$COUNT_FILE"

if [ "$count" -ge 3 ]; then
  mpv --no-video --really-quiet /home/bixcoitu/.config/hypr/scripts/mesaSom/faiz_end.wav >/dev/null 2>&1 &
  waypaper --wallpaper /home/bixcoitu/.config/hypr/scripts/⁄faiz.jpg
  echo 0 >"$COUNT_FILE"
fi
