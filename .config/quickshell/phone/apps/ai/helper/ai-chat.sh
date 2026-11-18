#!/usr/bin/env bash
# ai-chat.sh — manda um pedido ao /api/chat do Ollama, em streaming (NDJSON no stdout)
#
# Uso: ai-chat.sh '<json do pedido>' <url base do ollama>
#
# Por que existe: imagens (base64) e arquivos de texto passam fácil dos ~128 KB que
# cabem num argumento de linha de comando. Então o QML manda o JSON com marcadores
# no lugar do conteúdo grande, e este script troca cada marcador enquanto alimenta
# o curl por um pipe:
#   @@IMG:/caminho@@   vira o base64 da imagem
#   @@TXT:/caminho@@   vira o conteúdo do arquivo, já com escape de JSON
#
# O `exec` faz o curl virar o próprio processo: parar a resposta no Quickshell
# (SIGTERM) mata o curl de verdade e o Ollama para de gerar.

set -u

body="$1"
url="$2"

# conteúdo de um arquivo como texto dentro de uma string JSON (sem as aspas):
# tira caracteres de controle inválidos e CR, escapa \ " e tab, junta linhas com \n
json_escape() {
  tr -d '\000-\010\013\014\016-\037' < "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\r//g' \
    | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }'
}

build() {
  local rest="$body" pre path kind m

  while [[ "$rest" =~ @@(IMG|TXT):([^@]+)@@ ]]; do
    m="${BASH_REMATCH[0]}"
    kind="${BASH_REMATCH[1]}"
    path="${BASH_REMATCH[2]}"

    pre="${rest%%"$m"*}"
    rest="${rest#*"$m"}"

    printf '%s' "$pre"

    if [ "$kind" = IMG ]; then
      base64 -w0 -- "$path"
    else
      json_escape "$path"
    fi
  done

  printf '%s' "$rest"
}

exec curl -sN -X POST "$url/api/chat" \
  -H 'Content-Type: application/json' \
  --data-binary @<(build)
