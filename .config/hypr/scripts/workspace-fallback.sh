#!/usr/bin/env bash

# Sobre o script que vc verá, nao rode antes de ler, blz mano???
# --------------
# Ele basiciamente monitora o estado dos workspaces do Hyprland para evitar que o foco
# permaneça em um workspace vazio ou inválido após o fechamento de janelas.
#
# Lógica:
# 1. Obtém os clientes ativos do Hyprland através de `hyprctl -j clients`.
# 2. Identifica quais workspaces possuem janelas abertas.
# 3. Considera os workspaces persistentes definidos na configuração:
#    1, 2, 3, 4 e 6.
# 4. Verifica qual workspace está atualmente ativo e se ele ainda é válido.
# 5. Caso o workspace atual não seja mais válido, procura um workspace
#    persistente adequado para servir como fallback.
# 6. Se necessário, utiliza `hyprctl dispatch workspace` para mudar o foco.
# 7. Se o workspace atual continuar válido, nenhuma alteração é realizada.
#
# Ou Seja:
# Clientes -> Workspaces ocupados -> Verifica workspace atual
#          -> Válido? Sim -> não faz nada
#                   Não -> encontra fallback -> muda o workspace

set -u

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

declare -A WINDOW_WORKSPACE

CURRENT_WORKSPACE=""

initialize_state() {
  CURRENT_WORKSPACE=$(
    hyprctl -j monitors |
      jq -r '.[] | select(.focused == true) | .activeWorkspace.id'
  )

  while IFS=$'\t' read -r address workspace; do
    WINDOW_WORKSPACE["$address"]="$workspace"
  done < <(
    hyprctl -j clients |
      jq -r '.[] | [.address, .workspace.id] | @tsv'
  )
}

get_existing_workspaces() {
  hyprctl -j clients |
    jq -r '.[].workspace.id' |
    sort -nu
}

find_destination() {
  local current="$1"

  local previous
  previous=$(
    get_existing_workspaces |
      awk -v current="$current" '
                $1 < current {
                    previous = $1
                }

                END {
                    if (previous != "")
                        print previous
                }
            '
  )

  if [[ -n "$previous" ]]; then
    echo "$previous"
    return
  fi

  local next
  next=$(
    get_existing_workspaces |
      awk -v current="$current" '
                $1 > current {
                    print $1
                    exit
                }
            '
  )

  if [[ -n "$next" ]]; then
    echo "$next"
    return
  fi

  echo "$current"
}

focus_workspace() {
  local workspace="$1"

  hyprctl eval \
    "hl.dispatch(hl.dsp.focus({ workspace = \"$workspace\" }))"
}

workspace_has_windows() {
  local workspace="$1"

  hyprctl -j clients |
    jq -e --argjson workspace "$workspace" \
      'any(.[]; .workspace.id == $workspace)' \
      >/dev/null
}

handle_event() {
  local event="$1"
  local data="$2"

  case "$event" in

  workspacev2)
    CURRENT_WORKSPACE="${data%%,*}"
    ;;

  focusedmonv2)
    CURRENT_WORKSPACE="${data#*,}"
    ;;

  openwindow)
    local address="${data%%,*}"
    local remainder="${data#*,}"
    local workspace="${remainder%%,*}"

    if [[ "$workspace" =~ ^[1-9]$|^10$ ]]; then
      WINDOW_WORKSPACE["$address"]="$workspace"
    fi
    ;;

  movewindowv2)
    local address="${data%%,*}"
    local remainder="${data#*,}"
    local workspace="${remainder%%,*}"

    if [[ "$workspace" =~ ^[1-9]$|^10$ ]]; then
      WINDOW_WORKSPACE["$address"]="$workspace"
    fi
    ;;

  closewindow)
    local address="$data"

    local closed_workspace="${WINDOW_WORKSPACE[$address]:-}"

    unset 'WINDOW_WORKSPACE[$address]'

    [[ -z "$closed_workspace" ]] && return

    [[ "$closed_workspace" != "$CURRENT_WORKSPACE" ]] && return

    if workspace_has_windows "$closed_workspace"; then
      return
    fi

    local destination
    destination=$(find_destination "$closed_workspace")

    if [[ "$destination" == "$closed_workspace" ]]; then
      return
    fi

    focus_workspace "$destination"
    ;;

  esac
}

initialize_state

echo "Workspace fallback iniciado."
echo "Workspace atual: $CURRENT_WORKSPACE"
echo "Socket: $SOCKET"

socat -u "UNIX-CONNECT:$SOCKET" - |
  while IFS= read -r line; do

    event="${line%%>>*}"
    data="${line#*>>}"

    handle_event "$event" "$data"

  done
