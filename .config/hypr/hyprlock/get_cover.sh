#!/bin/bash

COVER="/tmp/spotify-cover.jpg"

STATUS=$(playerctl -p spotify status 2>/dev/null)

if [ -z "$STATUS" ]; then
  rm -f "$COVER"
  exit
fi
