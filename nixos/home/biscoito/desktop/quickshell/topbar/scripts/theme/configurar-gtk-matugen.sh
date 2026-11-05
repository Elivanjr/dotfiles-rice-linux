#!/usr/bin/env bash
# configurar-gtk-matugen.sh — faz o matugen colorir apps GTK (Nautilus, Blueman...)
#
# O que faz:
#   1. cria ~/.config/matugen/templates/gtk-colors.css
#   2. adiciona [templates.gtk3] e [templates.gtk4] no ~/.config/matugen/config.toml
#   3. troca os links simbólicos de ~/.config/gtk-3.0/gtk.css e gtk-4.0/gtk.css
#      (e gtk-4.0/gtk-dark.css) por arquivos de verdade que importam colors.css
#      - os links antigos apontavam pra cores fixas (dank-colors.css) e pro tema
#        adw-gtk3-dark, o que prendia os apps libadwaita no escuro
#
# Tudo que muda ganha backup com data: *.bak-tema-AAAAMMDD-HHMMSS
#
# Uso:
#   bash configurar-gtk-matugen.sh            aplica a configuração
#   bash configurar-gtk-matugen.sh --apply    aplica e já roda `tema.sh apply` (gera as cores)
#   bash configurar-gtk-matugen.sh --undo     desfaz (restaura o backup mais recente)
#
# Pode rodar mais de uma vez: o que já está configurado é pulado.

set -u

MATUGEN_DIR="$HOME/.config/matugen"
TPL_DIR="$MATUGEN_DIR/templates"
CONFIG="$MATUGEN_DIR/config.toml"
TPL="$TPL_DIR/gtk-colors.css"
STAMP="$(date +%Y%m%d-%H%M%S)"

IMPORT_LINE="@import 'colors.css';"

say() { printf '%s\n' "$*"; }
die() {
  printf 'ERRO: %s\n' "$*" >&2
  exit 1
}

latest_backup() {
  # backup mais recente de um arquivo (ou vazio)
  ls -1t "$1".bak-tema-* 2>/dev/null | head -n 1
}

# ----------------------------------------------------------------------
# --undo
# ----------------------------------------------------------------------
if [ "${1:-}" = "--undo" ]; then
  for f in "$HOME/.config/gtk-3.0/gtk.css" \
    "$HOME/.config/gtk-4.0/gtk.css" \
    "$HOME/.config/gtk-4.0/gtk-dark.css" \
    "$CONFIG"; do
    b="$(latest_backup "$f")"

    if [ -n "$b" ]; then
      rm -f "$f"
      mv "$b" "$f"
      say "restaurado: $f"
    else
      say "sem backup pra: $f"
    fi
  done

  say
  say "O template $TPL foi mantido (não atrapalha). Pode apagar se quiser."
  say "Reinicie os apps GTK abertos pra ver o resultado."
  exit 0
fi

[ -d "$MATUGEN_DIR" ] || die "pasta $MATUGEN_DIR não existe"
[ -f "$CONFIG" ] || die "arquivo $CONFIG não existe"

# ----------------------------------------------------------------------
# 1) template
# ----------------------------------------------------------------------
mkdir -p "$TPL_DIR"

NEW_TPL="$(mktemp)"
cat >"$NEW_TPL" <<'TEMPLATE_EOF'
/*
 * gtk-colors.css — gerado pelo matugen
 *
 * Mapeia os papéis do Material You para as "cores nomeadas" que a libadwaita
 * (Nautilus, etc.) e o adw-gtk3 (Blueman, apps GTK3) respeitam.
 * Importado por ~/.config/gtk-3.0/gtk.css e ~/.config/gtk-4.0/gtk.css via
 * @import 'colors.css';
 *
 * Não edite o arquivo gerado: edite este template em
 * ~/.config/matugen/templates/gtk-colors.css
 */

/* destaque (botões sugeridos, seleção, switches ligados) */
@define-color accent_color {{colors.primary.default.hex}};
@define-color accent_bg_color {{colors.primary.default.hex}};
@define-color accent_fg_color {{colors.on_primary.default.hex}};

/* ações destrutivas e erros */
@define-color destructive_color {{colors.error.default.hex}};
@define-color destructive_bg_color {{colors.error.default.hex}};
@define-color destructive_fg_color {{colors.on_error.default.hex}};
@define-color error_color {{colors.error.default.hex}};
@define-color error_bg_color {{colors.error.default.hex}};
@define-color error_fg_color {{colors.on_error.default.hex}};

/* janela e áreas de conteúdo (listas, campos de texto) */
@define-color window_bg_color {{colors.surface.default.hex}};
@define-color window_fg_color {{colors.on_surface.default.hex}};
@define-color view_bg_color {{colors.surface_container_lowest.default.hex}};
@define-color view_fg_color {{colors.on_surface.default.hex}};

/* barra de título */
@define-color headerbar_bg_color {{colors.surface_container.default.hex}};
@define-color headerbar_fg_color {{colors.on_surface.default.hex}};
@define-color headerbar_backdrop_color {{colors.surface.default.hex}};

/* barra lateral */
@define-color sidebar_bg_color {{colors.surface_container_low.default.hex}};
@define-color sidebar_fg_color {{colors.on_surface.default.hex}};
@define-color sidebar_backdrop_color {{colors.surface.default.hex}};

/* cartões, diálogos, menus e miniaturas */
@define-color card_bg_color {{colors.surface_container.default.hex}};
@define-color card_fg_color {{colors.on_surface.default.hex}};
@define-color dialog_bg_color {{colors.surface_container_high.default.hex}};
@define-color dialog_fg_color {{colors.on_surface.default.hex}};
@define-color popover_bg_color {{colors.surface_container_high.default.hex}};
@define-color popover_fg_color {{colors.on_surface.default.hex}};
@define-color thumbnail_bg_color {{colors.surface_container_high.default.hex}};
@define-color thumbnail_fg_color {{colors.on_surface.default.hex}};

/* nomes antigos do GTK3, pra apps que ainda usam */
@define-color theme_bg_color {{colors.surface.default.hex}};
@define-color theme_fg_color {{colors.on_surface.default.hex}};
@define-color theme_base_color {{colors.surface_container_lowest.default.hex}};
@define-color theme_text_color {{colors.on_surface.default.hex}};
@define-color theme_selected_bg_color {{colors.primary.default.hex}};
@define-color theme_selected_fg_color {{colors.on_primary.default.hex}};
TEMPLATE_EOF

if [ -f "$TPL" ] && cmp -s "$TPL" "$NEW_TPL"; then
  say "[template] já está atualizado: $TPL"
else
  [ -f "$TPL" ] && cp -a "$TPL" "$TPL.bak-tema-$STAMP"
  cp "$NEW_TPL" "$TPL"
  say "[template] escrito: $TPL"
fi

rm -f "$NEW_TPL"

# ----------------------------------------------------------------------
# 2) config.toml
# ----------------------------------------------------------------------
backed_up=0

add_template_block() {
  local name="$1" out="$2"

  # só conta se a tabela existe DESCOMENTADA
  if grep -qE "^\[templates\.${name}\][[:space:]]*$" "$CONFIG"; then
    say "[config] [templates.$name] já existe"
    return
  fi

  if [ "$backed_up" = 0 ]; then
    cp -a "$CONFIG" "$CONFIG.bak-tema-$STAMP"
    backed_up=1
  fi

  # garante uma linha em branco antes do bloco novo
  if [ -n "$(tail -c 1 "$CONFIG")" ]; then
    printf '\n' >>"$CONFIG"
  fi

  cat >>"$CONFIG" <<TOML_EOF

[templates.$name]
input_path = '~/.config/matugen/templates/gtk-colors.css'
output_path = '$out'
TOML_EOF

  say "[config] adicionado [templates.$name] -> $out"
}

add_template_block gtk3 '~/.config/gtk-3.0/colors.css'
add_template_block gtk4 '~/.config/gtk-4.0/colors.css'

# ----------------------------------------------------------------------
# 3) gtk.css de GTK3 e GTK4
# ----------------------------------------------------------------------
setup_gtk_css() {
  local dir="$1" f="$1/gtk.css"

  mkdir -p "$dir"

  if [ -L "$f" ]; then
    # link simbólico (dank-colors.css / tema adw-gtk3-dark): troca por arquivo real
    local alvo
    alvo="$(readlink "$f")"
    mv "$f" "$f.bak-tema-$STAMP"
    printf '%s\n' "$IMPORT_LINE" >"$f"
    say "[gtk] $f era link -> $alvo (backup guardado); agora importa colors.css"
  elif [ -f "$f" ]; then
    if grep -qF "$IMPORT_LINE" "$f"; then
      say "[gtk] $f já importa colors.css"
    else
      cp -a "$f" "$f.bak-tema-$STAMP"
      {
        printf '%s\n\n' "$IMPORT_LINE"
        cat "$f.bak-tema-$STAMP"
      } >"$f"
      say "[gtk] $f: import adicionado no topo (conteúdo antigo mantido embaixo)"
    fi
  else
    printf '%s\n' "$IMPORT_LINE" >"$f"
    say "[gtk] $f criado"
  fi
}

setup_gtk_css "$HOME/.config/gtk-3.0"
setup_gtk_css "$HOME/.config/gtk-4.0"

# gtk-dark.css apontando pro tema escuro também prendia o libadwaita no escuro
DARK="$HOME/.config/gtk-4.0/gtk-dark.css"

if [ -L "$DARK" ]; then
  mv "$DARK" "$DARK.bak-tema-$STAMP"
  say "[gtk] $DARK era link pro tema (backup guardado); removido"
fi

# ----------------------------------------------------------------------
# 4) gerar as cores agora (opcional)
# ----------------------------------------------------------------------
say
if [ "${1:-}" = "--apply" ]; then
  TEMA="$(dirname "$(readlink -f "$0")")/tema.sh"

  if [ -f "$TEMA" ]; then
    say "[apply] rodando: bash $TEMA apply"
    bash "$TEMA" apply
  else
    say "tema.sh não encontrado; rode o matugen na mão: matugen image <wallpaper>"
  fi
else
  say "Pronto. Pra gerar as cores agora:"
  say "  bash ~/.config/quickshell/topbar/scripts/theme/tema.sh apply"
  say "Depois reabra os apps GTK4 (Nautilus etc.); eles só leem o CSS ao abrir."
fi
