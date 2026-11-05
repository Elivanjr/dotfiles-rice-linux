#!/usr/bin/env bash
# tema.sh — alterna entre modo claro e escuro
#
# O que faz:
#   1. descobre o wallpaper atual (awww query; se falhar, lê o do waypaper)
#   2. roda `matugen image <wallpaper> -m <modo>`, que regenera TODOS os
#      templates do seu config.toml (quickshell, kitty, alacritty, rofi,
#      hyprland/colors.lua, vscode, vivaldi, obsidian, zen...)
#   3. troca GTK: gsettings (color-scheme + gtk-theme) e os settings.ini do
#      gtk-3.0 e gtk-4.0
#   4. recarrega o Hyprland pra aplicar as bordas novas
#   5. guarda o modo em ~/.local/state/quickshell/theme-mode
#
# Uso:
#   tema.sh dark | light          força o modo
#   tema.sh toggle                inverte o modo salvo
#   tema.sh apply [IMAGEM]        reaplica o modo salvo (use no post_command do
#                                 waypaper, assim trocar de wallpaper não
#                                 devolve o tema pro escuro)
#   tema.sh status                mostra modo salvo e wallpaper detectado
#   tema.sh dark /caminho/img.jpg usa essa imagem em vez do wallpaper atual
#
# Ajustes (variáveis de ambiente ou edite aqui):
#   TEMA_SYSTEM_WIDE=0   só matugen (não mexe em GTK/gsettings)
#   TEMA_RELOAD_HYPR=0   não roda `hyprctl reload`
#   TEMA_GTK_DARK / TEMA_GTK_LIGHT   nomes dos temas GTK de cada modo

set -u

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
STATE_FILE="$STATE_DIR/theme-mode"

SYSTEM_WIDE="${TEMA_SYSTEM_WIDE:-1}"
RELOAD_HYPR="${TEMA_RELOAD_HYPR:-1}"
GTK_DARK="${TEMA_GTK_DARK:-adw-gtk3-dark}"
GTK_LIGHT="${TEMA_GTK_LIGHT:-adw-gtk3}"

have() { command -v "$1" >/dev/null 2>&1; }
die()  { echo "tema.sh: $*" >&2; exit 1; }

current_mode() {
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
    return
  fi

  # sem estado salvo ainda: olha o que o GTK diz
  if [ "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" = "'prefer-light'" ]; then
    echo light
  else
    echo dark
  fi
}

wallpaper() {
  local img=""

  if have awww; then
    img="$(awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -n 1)"
  fi

  if [ -n "$img" ] && [ -f "$img" ]; then
    echo "$img"
    return
  fi

  # plano B: último wallpaper salvo pelo waypaper
  img="$(sed -n 's/^wallpaper *= *//p' "$HOME/.config/waypaper/config.ini" 2>/dev/null | head -n 1)"
  img="${img/#\~/$HOME}"

  if [ -n "$img" ] && [ -f "$img" ]; then
    echo "$img"
  fi
}

apply_gtk() {
  local mode="$1" scheme theme pref

  if [ "$mode" = dark ]; then
    scheme="prefer-dark"; theme="$GTK_DARK"; pref=1
  else
    scheme="prefer-light"; theme="$GTK_LIGHT"; pref=0
  fi

  if have gsettings; then
    gsettings set org.gnome.desktop.interface color-scheme "$scheme"
    gsettings set org.gnome.desktop.interface gtk-theme "$theme"
  fi

  # GTK3 também lê o settings.ini, então mantém os dois em sincronia
  local ini
  for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    [ -f "$ini" ] || continue
    sed -i \
      -e "s/^gtk-theme-name=.*/gtk-theme-name=$theme/" \
      -e "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=$pref/" \
      "$ini"
  done
}

apply_mode() {
  local mode="$1" img="$2"

  have matugen || die "matugen não encontrado"
  [ -n "$img" ] || die "não consegui descobrir o wallpaper atual (informe: tema.sh $mode /caminho/img.jpg)"
  [ -f "$img" ] || die "imagem não existe: $img"

  mkdir -p "$STATE_DIR"

  matugen image "$img" -m "$mode" || die "matugen falhou"

  echo "$mode" > "$STATE_FILE"

  if [ "$SYSTEM_WIDE" = 1 ]; then
    apply_gtk "$mode"
  fi

  if [ "$RELOAD_HYPR" = 1 ] && have hyprctl; then
    hyprctl reload >/dev/null 2>&1
  fi

  echo "modo $mode aplicado (imagem: $img)"
}

cmd="${1:-status}"

case "$cmd" in
  dark|light)
    apply_mode "$cmd" "${2:-$(wallpaper)}"
    ;;
  toggle)
    if [ "$(current_mode)" = dark ]; then
      apply_mode light "${2:-$(wallpaper)}"
    else
      apply_mode dark "${2:-$(wallpaper)}"
    fi
    ;;
  apply)
    apply_mode "$(current_mode)" "${2:-$(wallpaper)}"
    ;;
  status)
    echo "modo salvo: $(current_mode)"
    echo "wallpaper:  $(wallpaper)"
    ;;
  *)
    sed -n '2,28p' "$0"
    exit 1
    ;;
esac
