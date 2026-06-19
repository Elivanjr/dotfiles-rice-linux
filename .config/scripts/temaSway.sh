#!/usr/bin/bash

read -rp "Cor atual (ex:#FFFFFF): " COR_ATUAL
read -rp "Cor desejada: " COR_NOVA

if [[ ! "$COR_ATUAL" =~ ^#[0-9A-Fa-f]{6}$ ]] || [[ ! "$COR_NOVA" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
  echo "Cor inválida. Use o formato #RRGGBB"
  exit 1
fi

ARQUIVOS=(
  "$HOME/.config/wofi/style.css"
)

for ARQ in "${ARQUIVOS[@]}"; do
  if [ -f "$ARQ" ]; then
    sed -i "s/${COR_ATUAL}/${COR_NOVA}/g" "$ARQ"
    echo "✔ Atualizado: $ARQ"
  else
    echo "⚠ Arquivo não encontrado: $ARQ"
  fi
done

echo "✨ Troca concluída"
