#!/bin/sh
# Usado pelo ssh/scp (SSH_ASKPASS) do app SSH do celular.
# Não abre janela nenhuma: grava o prompt em um arquivo, o celular mostra um
# campo de senha na própria tela e devolve a resposta em outro arquivo.
d="${XDG_RUNTIME_DIR:-/tmp}/qs-phone-askpass"

mkdir -p "$d" && chmod 700 "$d"
rm -f "$d/reply" "$d/reply.tmp" "$d/cancel" "$d/prompt"

printf '%s\n' "$1" > "$d/prompt.tmp" && mv "$d/prompt.tmp" "$d/prompt"

i=0
while :; do
  if [ -e "$d/reply" ]; then
    cat "$d/reply"
    rm -f "$d/reply"
    exit 0
  fi

  if [ -e "$d/cancel" ]; then
    rm -f "$d/cancel"
    exit 1
  fi

  i=$((i + 1))
  [ "$i" -gt 600 ] && exit 1   # desiste depois de ~2 min

  sleep 0.2
done
