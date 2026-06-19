#!/usr/bin/bash

cliphist list | rofi -dmenu -i | cliphist decode | wl-copy
