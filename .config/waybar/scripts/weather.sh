#!/usr/bin/bash

#!/bin/bash
waybar-weather -config /home/bixcoitu/.config/waybar-weather/config.toml 2>/dev/null | grep '^{'
