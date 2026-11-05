# Booru Viewer para Quickshell

Um viewer independente, inspirado no painel de booru de `end-4/dots-hyprland`.
Ele é compatível com Quickshell 0.3.x e usa apenas QML/QtQuick.

## Executar

```sh
qs -p /caminho/para/booru-viewer/shell.qml
```

Ele abre como uma sidebar na esquerda. Quando desafixada, um clique fora, `Esc`
ou o botão `×` encerra o viewer independente; isso fecha somente o processo
iniciado por `qs -p`, nunca a sessão gráfica. Use `fixar` para deixar apenas a
sidebar capturando cliques.

Para integrar na sua topbar, use `BooruSidebar` da mesma forma que `AiSidebar`:
ligue `panelOpen` ao estado da sua interface e, em `onCloseRequested`, atualize
esse estado para `false`.

## Recursos

- Busca por tags e paginação.
- yande.re, Konachan, Danbooru, Gelbooru e Safebooru.
- Filtro seguro/NSFW, desligado inicialmente.
- Miniaturas, abertura do arquivo original e da fonte, quando disponível.

Alguns provedores podem bloquear requisições por política de rede, rate limit ou
exigirem autenticação. O viewer mostra a falha HTTP sem tentar contorná-la.

## Cores dinâmicas

`theme/Colors.qml` acompanha o arquivo do Matugen em
`~/.local/state/quickshell/generated/colors.json`. Quando seu trocador de
wallpaper gerar uma nova paleta, a sidebar atualiza as cores automaticamente.

## Pasta de downloads

Altere apenas `downloadDirectory` em `shell.qml` para definir onde o botão
**salvar no dispositivo** guarda as imagens. Por padrão: `~/Pictures/Booru`.
