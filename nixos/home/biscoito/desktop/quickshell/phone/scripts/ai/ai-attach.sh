#!/usr/bin/env bash
# ai-attach.sh — prepara um anexo (imagem ou arquivo de texto/código) pro chat de IA
#
# Uso: ai-attach.sh <arquivo>      imagem, texto ou código
#      ai-attach.sh -clip          imagem da área de transferência (precisa do wl-paste)
#
# Imprime UMA linha no stdout, com campos separados por TAB:
#   image <caminho>
#   text  <caminho> <nome original> <trunc|vazio>
#
# Imagens: copiadas pra XDG_RUNTIME_DIR/qs-ai (fica na RAM), sem transparência,
#   com rotação EXIF corrigida e reduzidas pra no máx. 1280 px em JPEG. Isso
#   importa: modelos de visão gastam tempo proporcional ao tamanho da imagem, e um
#   print em 4K vira uma espera enorme numa CPU. Sem ImageMagick, só copia.
# Texto/código: qualquer arquivo que não seja binário. Fica limitado a 60 KB (corta
#   na última linha inteira e avisa com "trunc") pra não estourar o contexto do modelo.
#
# Códigos de saída:
#   3 = não há imagem na área de transferência (ou falta o wl-paste)
#   4 = arquivo inexistente / ilegível
#   5 = o ImageMagick não conseguiu converter a imagem
#   6 = tipo não suportado (binário, PDF, vazio...)

set -u

MAX_TEXT=60000

src="$1"
dir="${XDG_RUNTIME_DIR:-/tmp}/qs-ai"
mkdir -p "$dir" || exit 4

stamp="$(date +%s%N)"
kind=""

if [ "$src" = "-clip" ]; then
  command -v wl-paste >/dev/null 2>&1 || exit 3
  type="$(wl-paste -l 2>/dev/null | grep -m1 '^image/')" || exit 3
  tmp="$dir/raw-$stamp"
  wl-paste -t "$type" > "$tmp" 2>/dev/null || { rm -f "$tmp"; exit 3; }
  [ -s "$tmp" ] || { rm -f "$tmp"; exit 3; }
  kind=image
else
  [ -f "$src" ] && [ -r "$src" ] || exit 4

  mime="$(file -b --mime-type -- "$src" 2>/dev/null || true)"

  case "$mime" in
    image/*)
      kind=image
      ;;
    "")
      # sem o comando `file`: decide pela extensão
      case "${src,,}" in
        *.png|*.jpg|*.jpeg|*.webp|*.gif|*.bmp) kind=image ;;
        *) kind=text ;;
      esac
      ;;
    *)
      kind=text
      ;;
  esac

  if [ "$kind" = image ]; then
    tmp="$dir/raw-$stamp"
    cp -- "$src" "$tmp" || exit 4
  fi
fi

# ---------- texto / código ----------
if [ "$kind" = text ]; then
  # grep -I rejeita binários; "." rejeita arquivo vazio
  grep -Iq . -- "$src" 2>/dev/null || exit 6

  dst="$dir/txt-$stamp"
  size="$(stat -c %s -- "$src")"
  trunc=""

  if [ "$size" -gt "$MAX_TEXT" ]; then
    trunc="trunc"
    # corta no limite e descarta a última linha (provavelmente pela metade)
    head -c "$MAX_TEXT" -- "$src" | sed '$d' > "$dst"
  else
    cp -- "$src" "$dst" || exit 4
  fi

  name="$(basename -- "$src" | tr -d '\t\n\r')"

  printf 'text\t%s\t%s\t%s\n' "$dst" "$name" "$trunc"
  exit 0
fi

# ---------- imagem ----------
out="$dir/img-$stamp.jpg"

if command -v magick >/dev/null 2>&1; then
  IM=magick
elif command -v convert >/dev/null 2>&1; then
  IM=convert
else
  IM=""
fi

if [ -n "$IM" ]; then
  "$IM" "$tmp[0]" -auto-orient -background white -alpha remove -alpha off \
    -resize '1280x1280>' -quality 88 "$out" 2>/dev/null \
    || { rm -f "$tmp" "$out"; exit 5; }
  rm -f "$tmp"
else
  mv -- "$tmp" "$out"
fi

printf 'image\t%s\n' "$out"
