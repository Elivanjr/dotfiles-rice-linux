#!/usr/bin/bash

class=$(playerctl metadata --player=spotify --format '{{lc(status)}}')
icon=" "

if [[ $class == "playing" ]]; then
  info=$(playerctl metadata --player=spotify --format '{{artist}} - {{title}}')

  info=$(echo "$info" | awk '{print substr($0,1,30)}')
  if [[ ${#info} -ge 30 ]]; then
    info="$info..."
  fi

  text="$icon $info"

elif [[ $class == "paused" ]]; then
  text="$icon"

elif [[ $class == "stopped" ]]; then
  text=""
fi

echo "{\"text\":\"$text\", \"class\":\"$class\"}"
