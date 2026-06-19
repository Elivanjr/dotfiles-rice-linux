#!/usr/bin/env bash

HOST="8.8.8.8"
LIMITE=300  # ms
INTERVALO=2 # segundos

ICON_DIR="$HOME/.config/scripts/media/Net/"
AUDIO="$HOME/Músicas/mesaSom/resenha?.mp4"

estado_antigo=""

while true; do
  ping_saida=$(LC_ALL=C ping -c 1 -W 2 "$HOST" 2>/dev/null)

  if [[ $? -eq 0 ]]; then
    latencia=$(awk -F'time=' '/time=/{split($2,a," "); print a[1]}' <<<"$ping_saida")

    if [[ -n "$latencia" ]] &&
      awk -v l="$latencia" -v lim="$LIMITE" 'BEGIN{exit !(l < lim)}'; then
      estado="online"
    else
      estado="lento"
    fi
  else
    estado="offline"
    latencia="---"
  fi

  if [[ "$estado" != "$estado_antigo" ]]; then
    case "$estado" in
    online)
      notify-send \
        "🟢 ONLINE" \
        "Ping: ${latencia} ms" \
        -i "$ICON_DIR/online.gif"

      if [[ -f "$AUDIO" ]]; then
        mpv --no-video "$AUDIO" >/dev/null 2>&1 &
      fi
      ;;

    lento)
      notify-send \
        "🟡 INTERNET LENTA" \
        "Ping: ${latencia} ms" \
        -i "$ICON_DIR/ok.png"
      ;;

    offline)
      notify-send \
        "🔴 OFFLINE" \
        "Sem resposta do servidor." \
        -i "$ICON_DIR/offline.png"
      ;;
    esac

    estado_antigo="$estado"
  fi

  sleep "$INTERVALO"
done
