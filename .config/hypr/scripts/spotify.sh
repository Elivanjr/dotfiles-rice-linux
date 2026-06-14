#!/bin/bash

PLAYER=""

# Detectar MPD
MPD_STATUS=$(mpc status 2>/dev/null)

if echo "$MPD_STATUS" | grep -q "\[playing\]\|\[paused\]"; then
  if echo "$MPD_STATUS" | grep -q "\[playing\]"; then
    ICON=""
  else
    ICON=""
  fi

  TRACK=$(mpc current)
  echo "󰎈 $ICON $TRACK"
  exit
fi

for p in $(playerctl -l); do
  # Ignorar Spotify
  if [[ "$p" == *"spotify"* ]]; then
    continue
  fi

  STATUS=$(playerctl -p "$p" status 2>/dev/null)

  if [ "$STATUS" = "Playing" ] || [ "$STATUS" = "Paused" ]; then
    PLAYER="$p"
    break
  fi
done

if [ -z "$PLAYER" ]; then
  echo "󰓛 Offline"
  exit
fi

STATUS=$(playerctl -p "$PLAYER" status)

if [ "$STATUS" = "Playing" ]; then
  ICON=""
else
  ICON=""
fi

# Detectar app
if [[ "$PLAYER" == *"brave"* ]]; then
  APP_ICON=" "
elif [[ "$PLAYER" == *"vlc"* ]]; then
  APP_ICON="󰕼 "
else
  APP_ICON=" "
fi

TRACK=$(playerctl -p "$PLAYER" metadata --format '{{artist}} - {{title}}' 2>/dev/null)

echo "$APP_ICON $ICON $TRACK"
