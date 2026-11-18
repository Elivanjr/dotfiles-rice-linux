#!/bin/sh
# Auxiliar do app Agendar do celular (usa o `at`; o atd já deve estar ativo).
#
#   at-schedule.sh add-t       QS_AT_CMD = comando, QS_AT_STAMP = AAAAMMDDhhmm (usado pelo calendário)
#   at-schedule.sh add         QS_AT_CMD = comando, QS_AT_WHEN = horário em texto do at (uso no terminal)
#   at-schedule.sh list        uma linha por job:  id<TAB>epoch<TAB>fila<TAB>comando
#   at-schedule.sh rm <id>     remove o job (atrm)
#
# O comando e o horário vêm por variável de ambiente (não por argv), assim
# aspas e espaços do comando chegam intactos ao `at`.
#
# A última linha impressa é sempre  __QS_RC__=<código>  para o celular ler
# a saída e o resultado juntos.

export LC_ALL=C

main() {
command -v at >/dev/null 2>&1 || { echo "O comando 'at' não está instalado."; return 127; }

case "$1" in
add-t)
  [ -n "$QS_AT_CMD" ] || { echo "Comando vazio."; return 2; }

  case "$QS_AT_STAMP" in
  [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) ;;
  *) echo "Data e hora inválidas."; return 2 ;;
  esac

  # o `at -t` aceita horário passado e roda o job na hora; aqui isso é erro
  agora=$(date +%Y%m%d%H%M)

  if [ "$QS_AT_STAMP" -le "$agora" ]; then
    echo "Esse horário já passou."
    return 2
  fi

  printf '%s\n' "$QS_AT_CMD" | at -t "$QS_AT_STAMP" 2>&1
  ;;

add)
  [ -n "$QS_AT_CMD" ] || { echo "Comando vazio."; return 2; }
  [ -n "$QS_AT_WHEN" ] || { echo "Horário vazio."; return 2; }

  set -f
  # shellcheck disable=SC2086
  set -- $QS_AT_WHEN

  case "$1" in
  -*) echo "Horário inválido."; return 2 ;;
  esac

  printf '%s\n' "$QS_AT_CMD" | at "$@" 2>&1
  ;;

list)
  out=$(atq 2>&1) || { printf '%s\n' "$out"; return 1; }

  printf '%s\n' "$out" | while IFS= read -r line; do
    [ -n "$line" ] || continue

    id=${line%%[[:space:]]*}
    rest=${line#"$id"}
    rest=$(printf '%s' "$rest" | sed 's/^[[:space:]]*//')

    # "Fri Oct 30 19:35:00 2026 a usuario"  ->  data | fila | usuário
    user=${rest##* }
    rest=${rest% *}
    queue=${rest##* }
    when=${rest% *}

    epoch=$(date -d "$when" +%s 2>/dev/null || echo 0)

    # comando = o que vem depois do bloco "cd ... || { ... }" do job
    cmd=$(at -c "$id" 2>/dev/null | awk '
      !body && /^cd .*\|\| *\{$/ { incd = 1; next }
      incd { if ($0 == "}") { incd = 0; body = 1 } ; next }
      body {
        if ($0 ~ /^\$\{SHELL:-\/bin\/sh\} <</) next
        if ($0 ~ /^marcinDELIMITER/) exit
        if ($0 != "") out = (out == "" ? $0 : out " ; " $0)
      }
      END { print out }' | tr '\t' ' ')

    printf '%s\t%s\t%s\t%s\n' "$id" "$epoch" "$queue" "$cmd"
  done
  ;;

rm)
  case "$2" in
  ''|*[!0-9]*) echo "Id inválido."; return 2 ;;
  esac

  atrm "$2" 2>&1
  ;;

*)
  echo "uso: at-schedule.sh add|list|rm <id>"
  return 2
  ;;
esac
}

main "$@"
rc=$?
printf '__QS_RC__=%s\n' "$rc"
exit "$rc"
