#!/bin/bash

POSITION=$(playerctl -p spotify position 2>/dev/null)
LENGTH=$(playerctl -p spotify metadata mpris:length 2>/dev/null)

LENGTH=$((LENGTH / 1000000))

if [ "$LENGTH" -le 0 ]; then
  exit
fi

CURRENT=${POSITION%.*}

format_time() {
  local T=$1
  printf "%d:%02d" $((T / 60)) $((T % 60))
}

CURRENT_FMT=$(format_time "$CURRENT")
TOTAL_FMT=$(format_time "$LENGTH")

PERCENT=$((CURRENT * 14 / LENGTH))

BAR=""

for ((i = 0; i < PERCENT; i++)); do
  BAR="${BAR}━"
done

for ((i = PERCENT; i < 14; i++)); do
  BAR="${BAR}─"
done

echo "$CURRENT_FMT [${BAR}] $TOTAL_FMT"
