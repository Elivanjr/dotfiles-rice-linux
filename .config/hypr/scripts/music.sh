#!/bin/bash

DEFAULT="/home/bixcoitu/Imagens/hyprlandWallpapers/cute.jpg"
declare -A MAP

MAP["rxyet - na rlk do 1155 do et"]="/home/bixcoitu/Imagens/songs/seco.gif"
MAP["sophie sanz - wonderful love"]="/home/bixcoitu/Imagens/songs/wonder.gif"
MAP["manuel - adrenaline"]="/home/bixcoitu/Imagens/songs/mf.gif"
MAP["lyn - take over"]="/home/bixcoitu/Imagens/hyprlandWallpapers/p5.jpg"
MAP["leslie parrish - king of the century"]="/home/bixcoitu/Imagens/songs/century.gif"

while true; do
  TRACK=$(playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null | tr '[:upper:]' '[:lower:]')

  if [ -z "$TRACK" ]; then
    if [ "$CURRENT" != "DEFAULT" ]; then
      CURRENT="DEFAULT"
      swww img "$DEFAULT" --transition-type any --transition-duration 3
    fi
  else
    if [ "$TRACK" != "$CURRENT" ]; then
      CURRENT="$TRACK"

      WALL="${MAP[$TRACK]}"

      if [ -n "$WALL" ]; then
        swww img "$WALL" --transition-type any --transition-duration 3
      fi
    fi
  fi

  sleep 1
done
