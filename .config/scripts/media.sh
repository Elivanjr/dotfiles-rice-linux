#!/bin/bash

PLAYER=$(playerctl -l 2>/dev/null | head -n1)

if [ -z "$PLAYER" ]; then
    echo '{"text": ""}'
    exit
fi

# remove .instanceXXXX
PLAYER_BASE=$(echo "$PLAYER" | cut -d'.' -f1)

ARTIST=$(playerctl metadata artist 2>/dev/null)
TITLE=$(playerctl metadata title 2>/dev/null)

TEXT="$ARTIST - $TITLE"

MAX=20W
if [ ${#TEXT} -gt $MAX ]; then
    TEXT="${TEXT:0:$MAX}..."
fi

ICON="$PLAYER_BASE"

case "$PLAYER_BASE" in
    brave|chromium|chrome|google-chrome)
        ICON=""
        ;;
    firefox)
        ICON=""
        ;;
    mpv)
        ICON="󰐹"
        ;;
esac

echo "{\"text\": \"$ICON $TEXT\"}"