#!/usr/bin/env bash

STATE_FILE="$HOME/.cache/sono-guard.json"
mkdir -p "$HOME/.cache"

# ----------------------------
# Estado padrão
# ----------------------------
default_state() {
  echo '{"contador":0,"ultima_execucao":"","ultimo_reset":"","ultima_hora":""}'
}

load_state() {
  [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || default_state
}

save_state() {
  echo "$1" >"$STATE_FILE"
}

state=$(load_state)

# ----------------------------
# Reset diário
# ----------------------------
hoje=$(date +%F)
ultimo_reset=$(echo "$state" | jq -r '.ultimo_reset // ""')

if [[ "$ultimo_reset" != "$hoje" ]]; then
  state=$(echo "$state" | jq \
    --arg d "$hoje" \
    '.contador = 0 | .ultimo_reset = $d')
  save_state "$state"
fi

# ----------------------------
# Loop principal
# ----------------------------
while true; do
  state=$(load_state)

  hour=$(date +%H)
  hora_atual=$(date +%Y%m%d%H)
  ultima_hora=$(echo "$state" | jq -r '.ultima_hora // ""')

  # Fora da janela (04h–22h)
  if ((10#$hour > 3 && 10#$hour < 23)); then
    sleep 300
    continue
  fi

  # Já perguntou nesta hora
  if [[ "$ultima_hora" == "$hora_atual" ]]; then
    sleep 30
    continue
  fi

  contador=$(echo "$state" | jq '.contador')

  resposta=$(
    timeout 1800 notify-send \
      -u critical \
      -t 0 \
      -A "sim=😴 Sim" \
      -A "nao=✨ Ainda estou acordado!" \
      "🌙 Guardião do Sono" \
      "$USER... você está com soninho?\nConfirmações: $contador"
  )

  exit_code=$?

  case "$exit_code" in
  124)
    state=$(echo "$state" | jq \
      --arg h "$hora_atual" \
      '.ultima_hora = $h')
    save_state "$state"

    systemctl poweroff 2>/dev/null || sudo systemctl poweroff
    ;;
  esac

  case "$resposta" in
  sim)
    state=$(echo "$state" | jq \
      --arg t "$(date -Iseconds)" \
      --arg h "$hora_atual" \
      '.ultima_execucao = $t
         | .ultima_hora = $h')
    save_state "$state"

    systemctl poweroff 2>/dev/null || sudo systemctl poweroff
    ;;

  nao)
    contador=$((contador + 1))

    state=$(echo "$state" | jq \
      --argjson c "$contador" \
      --arg t "$(date -Iseconds)" \
      --arg h "$hora_atual" \
      '.contador = $c
         | .ultima_execucao = $t
         | .ultima_hora = $h')
    save_state "$state"
    ;;
  esac

  sleep 30
done
