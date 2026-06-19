#!/usr/bin/bash

pkill eww 2>/dev/null
eww daemon
sleep 0.5
eww open booru
