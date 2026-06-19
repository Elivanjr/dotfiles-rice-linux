#!/bin/bash

COLORS="$HOME/.cache/wallust/colors.sh"

source "$COLORS"

cat >"$HOME/.config/hypr/colors.conf" <<EOF
\$active_border = rgba(ee${color4#\#})
\$active_border2 = rgba(ee${color5#\#})
\$inactive_border = rgba(aa${color8#\#})
EOF
