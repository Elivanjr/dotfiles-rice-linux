#!/usr/bin/bash

class=$(playerctl metadata --player=spotify --format '{{lc(status)}}' 2>/dev/null)
icon=""

if [[ $class == "playing" ]]; then
  artist=$(playerctl metadata --player=spotify artist)
  title=$(playerctl metadata --player=spotify title)
  album=$(playerctl metadata --player=spotify album)

  info="$artist - $title"

  short=$(echo "$info" | awk '{print substr($0,1,30)}')
  if [[ ${#info} -ge 30 ]]; then
    short="$short..."
  fi

  text="$icon $short"

  #  tooltip=" $title\n $artist\n󰀥 $album"
  tooltip="<big><b> $title</b></big>\n $artist\n󰀥 $album"

elif [[ $class == "paused" ]]; then
  text="$icon"
  tooltip="<big><b>󰏤 Spotify pausado</b></big>"

elif [[ $class == "stopped" ]]; then
  text=""
  tooltip=""

fi

echo "{\"text\":\"$text\", \"tooltip\":\"$tooltip\", \"class\":\"$class\"}"
