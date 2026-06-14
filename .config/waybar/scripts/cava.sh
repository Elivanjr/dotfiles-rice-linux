#!/usr/bin/bash
cava -p ~/.config/cava/config | while read -r line; do
  [ -z "$line" ] && continue

  bars=$(echo "$line" | tr ';' ' ')

  text=""
  for n in $bars; do
    if [ "$n" -gt 8 ]; then
      text="${text}█"
    elif [ "$n" -gt 7 ]; then
      text="${text}▇"
    elif [ "$n" -gt 6 ]; then
      text="${text}▆"
    elif [ "$n" -gt 5 ]; then
      text="${text}▅"
    elif [ "$n" -gt 4 ]; then
      text="${text}▄"
    elif [ "$n" -gt 3 ]; then
      text="${text}▃"
    elif [ "$n" -gt 2 ]; then
      text="${text}▂"
    elif [ "$n" -gt 1 ]; then
      text="${text}▁"
    else
      text="${text}▁"
    fi
  done

  [ -z "$text" ] && text="▁"

  printf '{"text":" %.30s"}\n' "$text"
done
