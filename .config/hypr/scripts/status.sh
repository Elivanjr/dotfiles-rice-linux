#!/bin/bash

# 🔋 BATERIA
BAT=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)

if [ -z "$BAT" ]; then
  BAT_INFO="🔋 N/A"
else
  if [ "$STATUS" = "Charging" ]; then
    ICON_BAT="󰂄"
  elif (( BAT <= 20 )); then
    ICON_BAT="󰁺"
  elif (( BAT <= 40 )); then
    ICON_BAT="󰁼"
  elif (( BAT <= 60 )); then
    ICON_BAT="󰁾"
  elif (( BAT <= 80 )); then
    ICON_BAT="󰂀"
  else
    ICON_BAT="󰁹"
  fi

  BAT_INFO="${ICON_BAT} ${BAT}%"
fi

# 📶 WIFI
WIFI=$(iwgetid -r 2>/dev/null)
[ -z "$WIFI" ] && WIFI=""

# 🌡️ TEMP
TEMP=$(sensors | grep 'Package id 0' | awk '{print $4}' | tr -d '+°C')
TEMP_INT=${TEMP%.*}

# 🎯 OUTPUT FINAL
echo " $(~/.config/hypr/scripts/spotify.sh) | ${BAT_INFO} |  ${WIFI} |  ${TEMP_INT}ºC"