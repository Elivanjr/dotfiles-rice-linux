#!/usr/bin/bash

if [-z "$1"]; then
  echo "Vocẽ não passou o caminho do video..."
  exit 1
fi

pkill mpvpaper
mpvpaper -o "loop --vo=gpu-next --hwdec=auto" "*" "$1" &
disown
