#!/usr/bin/env bash
# terminais-escuros.sh — deixa kitty e alacritty sempre com a paleta ESCURA do
# matugen, mesmo quando o tema do sistema está no modo claro.
#
# Como funciona: o matugen gera 3 variantes de cada cor (default, light, dark).
# Os templates usam {{colors.xxx.default.hex}}, que segue o modo do `matugen -m`.
# Aqui trocamos ".default." por ".dark." só nos templates dos terminais.
#
# Seguro de rodar mais de uma vez: guarda backup (.bak) só na primeira vez e
# não mexe em arquivo que não tenha ".default.".
#
# Pra desfazer: mv kitty.conf.bak kitty.conf (idem colors.toml.bak) e rode
#   ~/.config/quickshell/topbar/scripts/theme/tema.sh apply

set -eu

T="$HOME/.config/matugen/templates"

for f in "$T/kitty.conf" "$T/colors.toml"; do
  if [ ! -f "$f" ]; then
    echo "não achei $f" >&2
    exit 1
  fi

  n=$(grep -c '\.default\.' "$f" || true)

  if [ "$n" -eq 0 ]; then
    echo "$f: nenhuma ocorrência de .default. (já usa .dark. ou outra sintaxe), pulei"
    continue
  fi

  cp -n "$f" "$f.bak"
  sed -i 's/\.default\./.dark./g' "$f"
  echo "$f: $n linha(s) trocada(s)"
done

# regenera tudo com o modo salvo; kitty recarrega por SIGUSR1 e o alacritty
# recarrega sozinho quando o colors.toml muda
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/tema.sh" apply
