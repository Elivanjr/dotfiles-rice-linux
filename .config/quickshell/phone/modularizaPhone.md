# Modularização do Quickshell Phone

Documento de referência para a refatoração do projeto do celular (Quickshell, Hyprland, CachyOS).
Feito para ser lido por qualquer agente ou pessoa que pegue o projeto sem o histórico da conversa.

Regra que vale para tudo abaixo: **nenhuma etapa pode quebrar o aparelho.** Cada etapa sai como
um patch separado, e só avança depois do teste de aceitação passar no PC do usuário.

---

## 1. Contexto

O projeto é um "celular" desenhado em QML dentro do Quickshell. Cada app (chat, notícias, SSH, IA,
Bluetooth etc.) é uma tela, controlada por teclado e pelas softkeys. A navegação é feita pela variável
`phone.view`, e cada app é um objeto de lógica mais uma tela.

O código cresceu sem um padrão único. Funciona, mas adicionar um app exige mexer em quatro ou cinco
arquivos, e listas duplicadas já causaram bugs: a tela de notícias não recebia teclado porque faltava
na lista de views de `shell.qml`.

**Objetivo:** cada app vira uma unidade isolada. Um app novo é uma pasta mais uma linha de registro.
A infraestrutura compartilhada fica num lugar só.

---

## 2. Estado atual (linha de base)

Base: o `phone.zip` original mais os patches da seção 9. A base real precisa ser confirmada antes de
começar (ver seção 12).

Tamanho dos arquivos mais pesados:

| Arquivo | Linhas | Problema |
|---|---:|---|
| `logic/PhoneSettings.qml` | 2002 | Wi-Fi, Bluetooth, hotspot, OBEX e ajustes juntos |
| `logic/SshSession.qml` | 1343 | Túnel, navegador de pastas e terminal |
| `logic/AiChat.qml` | 1034 | Conversa com Ollama e anexos |
| `logic/CommandScheduler.qml` | 800 | Agendamento com `at` |
| `views/SettingsView.qml` | 730 | Navegação e telas de configuração |
| `shell.qml` | 601 | Instancia todos os apps e lista as views de foco |
| `logic/KeyControls.qml` | 443 | 113 referências a `phone.*`, cadeias de `if` |

Acoplamentos conhecidos:

- `KeyControls.qml` decide teclas e softkeys por cadeias `if (phone.view === "x")`. Cada app novo entra nelas.
- `shell.qml` mantém a lista de views que capturam teclado (`keyboardFocus` e `onViewChanged`), escrita
  à mão em dois lugares.
- `AppMenu.qml` e `MenuView.qml` mantêm, cada um, a sua lista de apps.
- `PhoneSettings.qml` tem a função `setRun`, que executa comandos com `sh -c "{ ... } 2>&1; echo __RC__=$?"`.

### 2.1 Inventário (projeto real)

Cruzamento de `logic/`, `views/` e `scripts/`. Cada linha vira uma pasta em `apps/`.

| App | Lógica | View | Scripts | Situação |
|---|---|---|---|---|
| chat | `apps/chat/ChatApp.qml` | `apps/chat/ChatView.qml` | `apps/chat/helper/` | etapa 4 aceita |
| news | `apps/news/NewsApp.qml` | `apps/news/NewsView.qml` | `apps/news/helper/` | etapa 4 aceita |
| share | `apps/screenshare/ScreenShareApp.qml` | `apps/screenshare/ShareView.qml` | (nenhum) | etapa 4 aceita |
| ai | `apps/ai/AiApp.qml` | `apps/ai/AiView.qml` | `apps/ai/helper/` | etapa 4 aceita |
| **terminal** | Terminal.qml | TermView.qml | (nenhum) | **remover (etapa 0)** |
| ssh | `apps/ssh/SshApp.qml` | `apps/ssh/SshView.qml` | (nenhum) | etapa 4 aceita |
| files | `apps/files/FilesApp.qml` | `apps/files/FilesView.qml` | (nenhum) | etapa 4 aceita |
| clipboard | `apps/clipboard/ClipboardApp.qml` | `apps/clipboard/ClipboardView.qml` | (nenhum) | etapa 4 aceita |
| download | `apps/downloader/DownloaderApp.qml` | `apps/downloader/DownloadView.qml` | `apps/downloader/helper/` | etapa 4 aceita |
| schedule | `apps/schedule/ScheduleApp.qml` | `apps/schedule/ScheduleView.qml` | `apps/schedule/helper/` | etapa 4 aceita |
| music | `apps/music/MusicApp.qml` | `apps/music/MusicView.qml` | (nenhum) | etapa 4 aceita |
| focus | `apps/focus/FocusApp.qml` | `apps/focus/FocusView.qml` | (nenhum) | etapa 4 aceita |
| calc | `apps/calculator/CalculatorApp.qml` | `apps/calculator/CalcView.qml` | (nenhum) | etapa 4 aceita |
| snake | `apps/snake/SnakeApp.qml` | `apps/snake/SnakeView.qml` | (nenhum) | etapa 4 aceita |
| info | `apps/info/InfoApp.qml` | `apps/info/InfoView.qml` | (nenhum) | etapa 4 aceita |
| wallpaper | `apps/wallpaper/WallpaperApp.qml` | `apps/wallpaper/WallpaperView.qml` | (nenhum) | etapa 4 aceita |
| settings | `system/settings/SettingsApp.qml` | `system/settings/SettingsView.qml` | (nenhum) | etapa 3 aceita |

Fica no núcleo ou é compartilhado, e não vira app:

- `AppMenu.qml`, `MenuView.qml`, `KeyControls.qml`: viram o registro, o menu e o despachante de teclas.
- `SystemStatus.qml`: barra de status (núcleo). Separado de `SystemInfo`, que é o app de informações.
- `ui/`: `SoftkeyBar`, `BodyButtons`, `StatusBar`, `ViewBase`, `Glyph`.
- `assets/phone.png`.

Arquivos `.orig` (`AppMenu`, `KeyControls`, `Glyph`, `MenuView`): são cópias do zip original,
sem uso. Saem na etapa 5, nunca antes.

---

## 2.2 Critérios para modularizar (APOO aplicado)

Os critérios abaixo vêm da metodologia de análise e projeto orientado a objetos (Wazlawick, UML/OCL),
adaptada ao caso do aparelho. A skill foi pensada para sistemas de informação; para QML de interface,
aproveitamos os princípios e deixamos de lado os artefatos que não se aplicam (casos de uso CRUD, ORM).

1. **Coesão alta.** Um módulo deve tratar de um conceito só. Dividir só quando um arquivo mistura
   conceitos. Exemplo real: `PhoneSettings.qml` (2002 linhas) junta Wi-Fi, Bluetooth, hotspot e OBEX.
   Esse é um caso que justifica dividir. `ViewBase`, `Glyph` e `SoftkeyBar` já são coesos: não mexer.
2. **Acoplamento baixo.** Um app não importa outro, e nenhum módulo central conhece os detalhes de um app.
   O teste prático: se adicionar um app obriga a editar um arquivo do núcleo, o núcleo está acoplado.
3. **Separação de camadas.** A lógica não toca em posição, cor ou tamanho; a tela não executa comando nem
   abre `Process`. Verificar as views em `apps/` e `system/settings/`.
4. **Responsabilidade no objeto que tem a informação.** O `KeyDispatcher` não decide o que cada app faz;
   ele entrega a tecla ao app ativo, e o app decide. Isso evita um despachante que concentra tudo.
5. **Comando e consulta separados.** Um comando (`ShellRunner.run` ou um `Process` do app) muda estado e
   tem resultado por callback. Uma consulta (estado do app, lista do menu) é uma propriedade, sem efeito colateral.
6. **Rastreabilidade.** Cada módulo novo precisa apontar para o que resolve: um bug real, uma lista duplicada
   ou um app. Módulo que não resolve nada concreto não entra.
7. **Detalhe na medida do necessário.** Criar a estrutura que a próxima etapa usa, não a que pode vir a ser
   usada. Se um padrão só tem um usuário, deixar no lugar até o segundo aparecer.

Esses critérios geram o escopo mínimo da seção 3.1.

## 3. Arquitetura alvo

```
phone/
├── shell.qml                  monta janela, painel e AppRegistry (não conhece apps)
├── assets/phone.png
│
├── core/                      infraestrutura e menu do sistema
│   ├── AppMenu.qml            estado e ações do menu
│   ├── KeyControls.qml        softkeys, D-pad e botões físicos
│   ├── AppDescriptor.qml      tipo com as propriedades de um app (sem lógica)
│   ├── AppRegistry.qml        lista explícita dos apps: ordem, busca, captura de teclado
│   ├── KeyDispatcher.qml      envia a tecla para o app ativo; sem consumo, trata Esc
│   ├── MenuView.qml           tela inicial do sistema
│   ├── MenuOptions.qml        popup de opções do menu
│   ├── SystemStatus.qml       dados da barra de status
│   ├── ShellRunner.qml        executa comandos do sistema (wrapper corrigido)
│
├── ui/                        componentes visuais reutilizáveis
│   ├── BodyButtons.qml
│   ├── Glyph.qml
│   ├── SoftkeyBar.qml
│   ├── StatusBar.qml
│   └── ViewBase.qml
│
├── apps/                      um diretório por app
│   ├── chat/
│   │   ├── ChatApp.qml        descritor + lógica + handleKey + softkeys
│   │   ├── ChatView.qml
│   │   └── helper/chat-helper.py
│   ├── news/      (NewsApp.qml, NewsView.qml, helper/news-helper.py)
│   ├── ai/        (AiApp.qml, AiView.qml, AiOptions.qml, helper/ai-chat.sh, ai-attach.sh)
│   ├── ssh/       (SshApp.qml, SshView.qml, SshOptions.qml)
│   ├── files/     (FilesApp.qml, FilesView.qml)
│   ├── downloader/(DownloaderApp.qml, DownloadView.qml, helper/ytdlp-helper.py)
│   ├── music/     (MusicApp.qml, MusicView.qml)
│   ├── calculator/(CalculatorApp.qml, CalcView.qml)
│   ├── clipboard/ (ClipboardApp.qml, ClipboardView.qml)
│   ├── schedule/  (ScheduleApp.qml, ScheduleView.qml, helper/at-schedule.sh)
│   ├── focus/     (FocusApp.qml, FocoView.qml)
│   ├── snake/     (SnakeApp.qml, SnakeView.qml)
│   ├── screenshare/(ScreenShareApp.qml, ShareView.qml)
│   ├── wallpaper/ (WallpaperApp.qml, WallView.qml)
│   └── info/      (InfoApp.qml, InfoView.qml)
│
├── system/
│   └── settings/
│       ├── SettingsView.qml   só navegação entre seções
│       ├── SettingsApp.qml    estado comum e roteamento
│       ├── SettingsOptions.qml popup de opções
│       ├── wifi/, bluetooth/, hotspot/, obex/
│
└── config/README.md           convenção de estado: ~/.config/quickshell-phone/<app>.json
```

Os nomes são o destino. Se algum precisar de outro nome por conflito, registrar na seção 10.

---

## 3.1 Escopo mínimo: o que criar e o que não criar

Pelos critérios 1 a 7, o núcleo fica pequeno. Cada item tem o motivo ao lado.

**Criar (etapas 1 e 2):**

- `AppDescriptor.qml`: tipo com as propriedades de um app. Motivo: hoje o app é descrito em quatro lugares.
- `AppRegistry.qml`: lista explícita dos descritores. Motivo: elimina as listas duplicadas em `shell.qml`,
  `AppMenu.qml` e `MenuView.qml`, que já causaram bug.
- `KeyDispatcher.qml`: entrega a tecla ao app ativo. Motivo: substitui as cadeias de `if` do `KeyControls.qml`.
- `ShellRunner.qml`: executa comandos com o wrapper corrigido. Motivo: já existe em duplicata e teve bug.

**Não criar agora:**

- `Theme.qml`: as cores e fontes estão repetidas, mas centralizar não resolve nenhum problema atual e
  amplia o escopo da migração. Revisar só se a troca de tema virar requisito.
- `HelperBridge.qml`: não implementado. Os helpers não compartilham um protocolo uniforme (Chat usa eventos
  JSON, Notícias retorna um documento, Baixar usa linhas de status e IA transmite NDJSON do Ollama); manter
  `Process` junto de cada app evita uma camada genérica que esconderia essas diferenças.
- Subpastas dentro de cada app (`helper/`, `scripts/`): criar só quando o app tiver mais de um helper.
  Enquanto houver um arquivo, ele fica na pasta do app.
- Módulos para os apps simples (calculadora, snake, relógio): ficam como pasta com dois arquivos.
  Não criar camada extra de lógica quando a tela só usa estado local.
- Separar `SystemStatus` de `SystemInfo` em módulos diferentes sem um motivo: ver seção 13.

**Limite da divisão do `settings`:** dividir o `PhoneSettings` por assunto (Wi-Fi, Bluetooth, hotspot, OBEX)
é o único corte grande que se justifica pelo critério 1. Os demais apps migram inteiros.

## 4. Contratos

### 4.1 Descritor de app (decisão: QML, não JSON)

Cada app declara o seu descritor em QML, dentro da própria pasta. O registro é uma lista explícita
de descritores, e não uma leitura de arquivos em tempo de execução.

```qml
// apps/chat/ChatApp.qml
// Chat entre aparelhos (socket TCP). Descritor, lógica e teclado num arquivo só.
import QtQuick
import Quickshell

AppDescriptor {
  id: "chat"
  name: "Chat"
  icon: "chat"                 // nome do Glyph
  tileColor: "#3d7bd9"
  keywords: ["mensagens", "socket", "aparelho", "tcp"]
  showInMenu: true
  capturesKeys: true           // substitui a lista escrita à mão em shell.qml

  logic: ChatLogic { }         // criado uma vez e mantido vivo
  view: ChatView { }

  softLeftText: logic.chatSoftLeft
  softCenterText: logic.chatSoftCenter
  softRightText: "Voltar"

  onKey: (e) => logic.handleChatKey(e)
  onSoftLeft: logic.softLeft()
  onSoftCenter: logic.softCenter()
  onBack: logic.chatBack()
}
```

Por que QML e não `app.json`: o registro de QML compila junto com o projeto, o `qmllint` pega erro
antes de rodar, e não depende de ler arquivos em tempo de execução. Se um dia a leitura de JSON for
confirmada na versão do Quickshell do usuário, a troca é mecânica.

`AppDescriptor` é um tipo novo (`core/AppDescriptor.qml`). Ele só guarda propriedades; não tem lógica.

### 4.2 Interface de um app de lógica

Todo `XxxLogic.qml` expõe:

```qml
property var phone                      // raiz, para acessar Theme e serviços
readonly property string softLeftText
readonly property string softCenterText
function handleKey(e) { ... }           // e.accepted = true quando consumir
function softLeft() { ... }
function softCenter() { ... }
function onEnter() { ... }              // opcional: chamado ao abrir a tela
```

Regras:

- O `softRight` padrão volta ao menu. Só sobrescrever se o app tiver um "voltar interno"
  (ex.: o chat volta da conversa para a configuração).
- Tecla não consumida (`e.accepted` continua falso) é tratada pelo `KeyDispatcher`
  (ex.: Esc sem nada aberto volta ao menu).

### 4.3 `ShellRunner.qml`

```qml
function run(label, script, args, env, okMessage, onDone)
// onDone(rc: int, lines: string[])
```

Obrigatório:

- O script vai dentro de subshell: `( script ) 2>&1; echo __RC__=$?`.
  **Nunca usar `{ ... }`.** Um `exit` dentro de chaves encerra o shell antes do `__RC__`, e o
  resultado vira falha falsa. Esse foi o bug do Bluetooth.
- Remover códigos ANSI antes de mostrar: `line.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "")`.
- Um comando por vez (`busy`), como o `setRun` atual.

### 4.4 Processos dos helpers

Cada app mantém seu `Process` e parser junto de sua lógica. Não há `HelperBridge` compartilhado porque
Chat, Notícias, Baixar e IA usam protocolos de entrada e saída diferentes.

### 4.5 `AppRegistry.qml`

```qml
readonly property var apps          // ordem do menu
readonly property var keyApps       // ids que captam teclado
function appById(id)
function activeApp()                // app da tela atual (phone.view)
function open(id)                   // abre um app a partir de outro
```

`shell.qml` usa o registro para montar menu e busca, e para calcular `keyboardFocus` e `onViewChanged`.
As listas escritas à mão somem.

### 4.6 `KeyDispatcher.qml`

Recebe a tecla e chama `registry.activeApp().handleKey(e)`. Se o app não consumir, aplica o tratamento
global. Substitui as cadeias de `if` do `KeyControls.qml`.

---

## 5. Convenções

- Um app = uma pasta em `apps/`. Nada de app novo em `logic/` ou `views/`.
- Nenhum app importa outro diretamente. Comunicação via `phone` ou via `registry.open(id)`.
- Estado persistente vai em `~/.config/quickshell-phone/<id>.json`. Nunca em caminhos fixos do usuário.
- Helpers Python ficam em `apps/<id>/helper/`. Shell que não é de um app específico fica em `scripts/`.
- Textos de interface e comentários em português. Nomes já existentes não são traduzidos só por estética.
- Cada arquivo começa com um comentário de uma linha dizendo o que é e onde é usado.
- Nenhuma lista duplicada: se duas partes precisam da mesma lista de apps, uma lê do registro.
- Nenhum `.orig` ou backup dentro do projeto. Backups ficam fora da árvore.

---

## 6. Plano de execução

Cada etapa é um patch separado. Não avançar sem o teste de aceitação da etapa atual passar no PC do usuário.

### Etapa 0 — Remover o app Terminal

**Status:** remoção aplicada e aceita pelo usuário no PC.

Decisão do usuário: o Terminal (bash local) sai do aparelho. Nada depende dele. O terminal do SSH
(`sshMode === "term"` dentro de `SshSession.qml`) é outro código e continua.

- [x] Apagar `logic/Terminal.qml` e `views/TermView.qml`.
- [x] `shell.qml`: instância `term`, o `termEnter()` ao abrir a view, e `"term"` nas duas listas de foco.
- [x] `logic/KeyControls.qml`: bloco `if (phone.view === "term")` em `handleKey`, ramos de `softLeft`,
      `softCenter`, `softRight`, textos das softkeys, e `"term"` na condição compartilhada com `calc` e `snake`.
- [x] `logic/AppMenu.qml`: item `{ term: true, ... }` e o ramo `if (item.term)`. As palavras de busca
      "terminal" aparecem em mais de um bloco; remover só o item do Terminal.
- [x] `views/MenuView.qml`: tile do Terminal (`modelData.term === true`) e a exclusão `modelData.term !== true`
      da letra de fallback.
- [x] Não remover o Glyph `"terminal"`: o tile do SSH usa.

Aceitação confirmada pelo usuário: menu/busca, retorno por Esc e softkeys, terminal interno do SSH e log.

Antes de apagar: `grep -rn "term" --include=*.qml` e conferir que o restante é do SSH (`sshMode`,
`sshTerm...`) ou do ícone.

Aceitação:
- O menu não mostra mais o Terminal, nem na lista nem na busca.
- A busca continua encontrando o SSH, se ele tiver essa palavra.
- Calculadora e Snake voltam ao menu com Esc e com a softkey.
- O modo terminal do SSH continua funcionando.
- Nenhum `phone.term is undefined` no log de `qs -c phone`.

Se algum teste falhar, reverter o patch inteiro da etapa.

### Etapa 1 — `ShellRunner` e `AppRegistry` (sem mover nada)

**Status 1a (ShellRunner):** implementado e aceito pelo usuário. O `setRun` de `PhoneSettings` delega a
execução e o tratamento da saída a `core/ShellRunner.qml`.

**Status 1b (AppRegistry):** implementado e aceito pelo usuário no aparelho.
`AppDescriptor.qml` guarda metadados do app; `AppRegistry.qml` fornece o catálogo, a busca por id, a tela
ativa, a abertura de apps e as telas que capturam teclado. O menu visual e a busca usam os descritores.

- [x] Criar `core/ShellRunner.qml` com o wrapper corrigido (4.3).
- [x] Trocar o `setRun` do `PhoneSettings.qml` para usar `ShellRunner`.
- [x] Criar `core/AppDescriptor.qml` e `core/AppRegistry.qml` com lista explícita de descritores.
- [x] `shell.qml` calcula `keyboardFocus` e trata a entrada nas telas pelo registro.
- [x] `AppMenu.qml` e `MenuView.qml` leem do registro.

Verificações locais da 1b: `qmllint` passou em `AppDescriptor.qml`, `AppRegistry.qml`, `AppMenu.qml` e
`MenuView.qml`. `qmllint` continuou saindo com código 255, sem diagnóstico, em `shell.qml`. O usuário
confirmou no aparelho que o menu, a busca, o foco/Esc e a abertura das telas funcionam.

Verificações locais da 1a: `qmllint` passou em `ShellRunner.qml`; os casos de shell retornaram 0 e 7 como
esperado. `qmllint` saiu com código 255 sem diagnóstico em `shell.qml` e `PhoneSettings.qml`; não consegui
validar esses arquivos por essa ferramenta. O usuário confirmou que a etapa funcionou no aparelho.

Correção posterior: o log de inicialização reportou `color is not a type` em `AppDescriptor.qml`. O arquivo
importava apenas `QtQml`, embora declare propriedades `color`; o import foi trocado para `QtQuick`. A nova
inicialização ainda precisa ser confirmada no aparelho.

Log de inicialização seguinte: configuração carregou, mas reportou possível ciclo em `clipCurrent` e fundo
do vidro ausente em `~/Imagens/hyprlandWallpapers/celularbg.png`. A seleção do Clipboard agora é atualizada
explicitamente ao mudar lista/filtro, sem depender de `onClipFilteredChanged`; o fundo padrão foi alinhado
ao arquivo existente `~/Imagens/celularBG/cute.png`, que também é o caminho salvo pelo usuário. Os avisos
Wayland `QWaylandTextInputv3::disableSurface` permanecem sem evidência de impacto funcional.

Aceitação:
- Conectar Bluetooth a um aparelho pareado: sem card de erro, barra mostra "Conectado a ...".
- Conectar a um aparelho inexistente: card com texto sem códigos ANSI.
- Esc volta ao menu em todas as telas, sem clique.
- Todas as telas do menu abrem.

### Etapa 2 — `KeyDispatcher` e interface de app

- [x] Criar `core/KeyDispatcher.qml`.
- [x] Converter Chat e Notícias para a interface 4.2 (são os mais recentes e já têm `handleKey`).
- [x] Remover os blocos deles de `KeyControls.qml`.
- [x] Converter os demais apps em trios por rodada, como solicitado pelo usuário; validar cada trio antes do próximo.

Status: Chat, Notícias, Calculadora, Cobrinha, Foco, Música, Wallpaper, Clipboard, Baixar, Agendar,
Informações, Arquivos e Compartilhar tela foram aceitos pelo usuário. Em Informações, foi corrigida a
captura do teclado para que Esc seja entregue ao app.

IA e SSH expõem `handleKey` e a interface de softkeys; suas lógicas foram ligadas ao `AppRegistry`
e os despachos específicos foram removidos de `KeyControls.qml`. Menu e Configurações agora também
implementam `handleKey` e a interface de softkeys. `KeyDispatcher` chama somente a interface do módulo
ativo, sem fallback para despacho legado. Mudança aplicada; aguarda validação do usuário.

Verificação local desta rodada: `qmllint` passou em `KeyControls.qml` e `AppRegistry.qml`. Em `AiChat.qml`
e `SshSession.qml`, retornou código 255 sem diagnóstico, limitação já observada em alguns arquivos QML.
Busca confirmou que `KeyControls.qml` não conserva referências específicas a IA ou SSH. A verificação
de runtime segue no PC do usuário.

Aceitação: cada app recebe teclas, as softkeys funcionam, Esc se comporta como antes em todos.

### Etapa 3 — Dividir `PhoneSettings.qml`

Primeira passada implementada e validada: a lógica inteira foi movida para `system/settings/SettingsApp.qml`,
e a tela para `system/settings/SettingsView.qml`. `shell.qml` instancia `SettingsApp` como `phone.config`;
a tela importa os componentes compartilhados de `ui/`.

Ordem, da menos arriscada para a mais arriscada:

- [x] Bluetooth (inclui OBEX)
- [x] Hotspot
- [x] Wi-Fi
- [x] `SettingsApp.qml` mantém a fachada comum e o roteamento.

Bluetooth, Hotspot e OBEX foram extraídos e validados pelo usuário. `BluetoothSettings.qml` concentra o
estado, leitura dos dispositivos, descoberta, conectar/desconectar, seleção e transferência de arquivos.
`HotspotSettings.qml` concentra credenciais, estado, cálculo do plano, QR Code e operações de ligar/desligar.
`SettingsApp.qml` mantém a fachada para `phone.config`, a apresentação das seções e o roteamento dos
formulários.

Wi-Fi foi extraído para `WifiSettings.qml` e validado pelo usuário. O módulo concentra estado, varredura,
parsing, ligar/desligar rádio, conexão e remoção de redes salvas. Com isso, a etapa 3 está concluída.

Verificação local: `qmllint` passou em `BluetoothSettings.qml`, `HotspotSettings.qml`, `WifiSettings.qml` e
`SettingsView.qml`. Em `SettingsApp.qml`, retornou código 255 sem diagnóstico, limitação recorrente nesse
arquivo.

Correção posterior: o log de inicialização revelou aliases apontando para nomes de propriedade como se fossem
IDs QML (`hotspot`, `wifi`, `bluetooth`). Os três objetos agora têm IDs explícitos (`hotspotModule`,
`wifiModule`, `bluetoothModule`) e a fachada aponta os aliases para esses IDs. Um segundo log mostrou que o
estado Bluetooth se chama `powered`, não `power`; `setBtOn` agora aponta para a propriedade correta. Falta
confirmar no aparelho que a configuração inicia e que Configurações abre normalmente.

Aceitação por etapa: a tela de Configurações abre e todas as seções existentes continuam acessíveis.
Aceitação por subsistema: as ações funcionam como antes, inclusive o caminho de erro.

### Etapa 4 — Mover apps para `apps/<id>/`

Em trios por rodada, conforme preferência atual do usuário: chat, notícias, info, calculadora, snake, relógio/agenda, clipboard, música, foco,
wallpaper, arquivos, downloader, SSH, IA, screenshare. (Terminal já saiu na etapa 0.)

Chat e Notícias foram movidos para `apps/chat/` e `apps/news/`, incluindo suas views e helpers. Os QML
resolvem os helpers dentro das pastas dos apps com `Qt.resolvedUrl`.

Informações e Calculadora foram movidas para `apps/info/` e `apps/calculator/`, incluindo suas views.
O registro central mantém as propriedades `phone.info` e `phone.calc`; o usuário autorizou seguir para a
rodada seguinte.

Cobrinha, Agendar e Clipboard foram movidos para `apps/snake/`, `apps/schedule/` e `apps/clipboard/`,
incluindo suas views e o helper do agendador. O usuário validou o trio. O registro central mantém
`phone.snake`, `phone.sched` e `phone.clip`.

Música, Foco e Wallpaper foram movidos para `apps/music/`, `apps/focus/` e `apps/wallpaper/`, incluindo
suas views; o usuário validou o trio. O registro central mantém `phone.music`, `phone.foco` e `phone.walls`.

Arquivos, Baixar e SSH foram movidos para `apps/files/`, `apps/downloader/` e `apps/ssh/`, incluindo as
views e o helper yt-dlp. O usuário validou o trio. O `askpass.sh` de phone não tinha referência ativa e
foi removido na etapa de limpeza. Como instâncias antigas do Quickshell continuaram pedindo os caminhos
`scripts/`, foram criados aliases de compatibilidade para os helpers antigos de Chat, Notícias, IA e Baixar.
Os QML atuais continuam resolvendo os helpers dentro das pastas de `apps/`.

IA e Compartilhar tela foram movidos para `apps/ai/` e `apps/screenshare/`, incluindo suas views e os dois
helpers de IA. O registro central mantém `phone.ai` e `phone.share`; o usuário validou o par. Os aliases
de compatibilidade de Chat, Notícias, IA e yt-dlp apontam para os helpers atuais.

Verificação local da rodada anterior: `qmllint` passou nos cinco arquivos QML; `WallpaperApp.qml` e
`shell.qml` retornaram código 255 sem diagnóstico. Rodada atual: `qmllint` passou nos quatro arquivos
QML exceto `AiApp.qml`, que retornou 255 sem diagnóstico. `sh -n` passou nos dois helpers de IA, e a busca
não encontrou referências QML aos caminhos antigos.

Para cada app:
- [ ] criar `apps/<id>/` com o descritor `<Nome>App.qml`;
- [ ] mover lógica, tela e helper;
- [ ] ajustar caminhos dos helpers (`Qt.resolvedUrl`);
- [ ] remover as referências antigas;
- [ ] `grep -rn "phone\.<app>"` antes de mover, para achar todas as referências;
- [ ] testar o app isoladamente.

### Etapa 5 — Limpeza

- [x] Remover `logic/` e `views/` antigos quando estiverem vazios.
- [x] Remover os `.orig`.
- [x] Mover popups específicos do menu, SSH, IA e Configurações para os módulos que os usam.
- [x] Manter aliases de compatibilidade para os caminhos antigos de Chat, Notícias, IA e yt-dlp; todos apontam para os helpers atuais.

Limpeza concluída: `AppMenu`, `KeyControls`, `MenuView` e `SystemStatus` estão em `core/`;
`OptionPopups.qml` foi dividido entre o menu, SSH, IA e Configurações. `ui/` contém só peças visuais
compartilhadas. O `askpass.sh` da pasta phone foi removido por não haver referência ativa a ele; o Topbar
mantém seu próprio helper independente. `scripts/` contém somente aliases para caminhos antigos de Chat,
Notícias, IA e yt-dlp, necessários para instâncias do Quickshell que ainda os chamem. Os QML atuais resolvem
seus helpers diretamente dentro das pastas dos apps.

---

## 7. Como testar sem o QML rodar no agente

- Scripts Python: `python3 -m py_compile`, e teste com fixture quando houver lógica pura.
- Scripts de shell: `sh -n` para sintaxe; para o fluxo de `__RC__`, `sh -c` com um comando falso.
- Shell embutido em QML: extrair o texto do template literal, trocar `\$` por `$` e rodar com
  `pactl`/`hyprctl` falsos (foi assim que se testou o som na TV).
- QML: `qmllint` nos arquivos alterados. Como fallback, checagem de balanceamento de chaves e
  parênteses; cuidado, porque regex simples erra com barras em strings (`/\x1b\[.../`).
- Patches: `diff -ruN a b > x.patch`, aplicar numa cópia limpa com `patch -p1 --dry-run` antes de entregar.
- Interface: sempre no PC do usuário, com `qs -c phone`. No relatório, listar o que foi testado e o que não foi.

Não declarar uma etapa concluída sem o teste de aceitação ser feito pelo usuário, ou sem registrar
a limitação.

---

## 8. Riscos conhecidos

- **Referências espalhadas.** Mover a instância de um app pode quebrar `phone.<app>` em outro lugar.
  Buscar todas as ocorrências antes de mover.
- **`Process.write()`** é usado pelo Chat e pelo Terminal. Se a versão do Quickshell não tiver, o chat
  precisa de outro caminho de envio.
- **Leitura de JSON/FileView.** Não confirmada na versão do usuário. Por isso o descritor é QML (4.1).
- **Estado que sobrevive à view.** Chat e SSH mantêm processos vivos quando a tela some. O registro
  cria a lógica uma vez e não recria ao abrir.
- **Dependências entre apps.** `ScreenShare` depende de `PhoneSettings` (ambos mexem em monitores).
  Antes de mover, decidir se a dependência vira módulo do núcleo.
- **Feeds de notícia** podem falhar ou mudar de endereço. O erro aparece no rodapé; não é bug do código.
- **Modularização excessiva.** O risco mais provável deste projeto é criar camadas que ninguém usa.
  Antes de cada módulo novo, aplicar os critérios da seção 2.2 e registrar qual problema ele resolve.
- **Chat sem criptografia nem autenticação.** Ver seção 11.

---

## 9. Mudanças já entregues (aplicar nesta ordem)

Todas em `/mnt/user-data/outputs/`. Patches ou arquivos novos sobre o `phone.zip`.

1. **Chat entre aparelhos.** `chat-install.zip` (`install.sh`, `chat.patch`, `files/`): `scripts/chat/chat-helper.py`,
   `logic/Chat.qml`, `views/ChatView.qml` e alterações em `shell.qml`, `KeyControls.qml`, `AppMenu.qml`, `MenuView.qml`.
   O `install.sh` faz backup antes. Protocolo: TCP puro, uma linha JSON `{"m": "texto", "n": "nome"}` por mensagem, porta 5055.
2. **Foco da notícia (ESC).** `sed -i 's/|| view === "chat")/|| view === "chat" || view === "news")/g' shell.qml`.
   Deixa de ser necessário na etapa 1, porque o registro calcula a lista.
3. **Notícias: rodapé duplicado.** `news-rodape.patch`: remove o rodapé da `NewsView.qml`.
4. **Notícias por tópico.** `news-topicos.patch`: tecnologia, jogos, animes e política; filtro em `news-feeds.json`
   (campo `excluir`); cache versão 2. Depende do item 3. Depois: `python3 scripts/news/news-helper.py init --recriar`.
5. **Bluetooth: falso erro na conexão.** `bluetooth-rc.patch`: wrapper `{ }` trocado por `( )`, e remoção de ANSI.
   A etapa 1 coloca essa mesma correção em `ShellRunner.qml`.
6. **Cliente de terminal do chat (uv).** `chat-tui.zip` (`chat.py`, `install.sh`, `LEIA-ME.txt`). Independente do
   projeto do celular.
7. **Busca nas notícias, aba Linux e parser RSS 1.0.** `news-busca.patch`, `news-linux.patch`.
8. **Som na TV no compartilhamento.** `tela-som-tv.patch`, depois `tela-som-tv-fix.patch` (perfil HDMI da placa
   e restauração), e `tela-texto.patch` (descrição de "Unir telas").
9. **Projeto consolidado.** `phone-projeto.zip` já com todos os itens acima aplicados, e `HANDOFF.md`.

Testes feitos aqui:
- Itens 1 a 5 e 7 a 8: patch aplicado em cópia limpa, sintaxe verificada.
- Item 1: helper e cliente de terminal trocaram mensagens nos dois sentidos.
- Itens 4 e 7: filtro e parser testados com XML de exemplo; RSS real não testado (sandbox sem acesso aos sites).
- Item 5: wrapper testado com `sh` (sucesso, falha, ANSI).
- Item 8: scripts de som testados com `pactl`/`hyprctl` falsos, nos casos com e sem áudio da TV.
- Item 6: interface testada em modo headless e comparada numa captura.

Nenhum item foi executado no QML. Todos precisam de teste no PC do usuário.

---

## 10. Decisões tomadas

Os critérios de modularização seguem a skill APOO (`apoo-uml-ocl`): coesão alta, acoplamento baixo e
responsabilidade no objeto que tem a informação. Quando uma mudança não reduz acoplamento nem
aumenta coesão, ela fica fora do escopo.

| Decisão | Motivo |
|---|---|
| Chat com TCP puro, não WebSocket | Não há cliente de navegador. WebSocket só compensaria para acesso via web. |
| Notícias por tópico, não por região | O usuário quer tecnologia, jogos, animes e política/urgente. Fofoca, BBB, famosos, novelas e música ficam de fora. |
| Filtro de notícias em lista editável no JSON | Ajustar sem mexer em código. |
| Abas de notícia viraram seletor com setas | Quatro abas não cabem em 264 px. |
| Anime em inglês (Anime News Network) | Não achei feed de anime em português confiável. |
| Descritor de app em QML, não `app.json` | Sem leitura de arquivo em tempo de execução; checável por `qmllint`. Migração para JSON é mecânica se for confirmada. |
| Remover o app Terminal | Decisão do usuário. Nada depende dele; o terminal do SSH é código separado. |
| Modularizar só onde a coesão é baixa (critério APOO 1) | Evita estrutura sem uso; a divisão do `settings` é a exceção justificada. |
| Sem `Theme.qml` por enquanto | Nenhum problema atual exige; ampliaria a migração sem ganho. |
| Sem `HelperBridge` genérico | Cada app usa um protocolo de helper diferente; `Process` fica no app que entende esse protocolo. |
| Tecla R fora da lista de notícias | Conflitava com a digitação da busca. Atualizar agora é F5. |
| Pastas por app só para o que for refatorado | Mover arquivo sem mudar o contrato só troca o caminho; não melhora acoplamento. Custa risco e não traz ganho. |
| Etapas pequenas, uma de cada vez, com teste entre elas | O aparelho não pode quebrar. Cada patch é revertível sozinho. |
| Som na TV automático ao compartilhar | Pedido do usuário. Um interruptor pode vir depois. |

Novas decisões entram nesta tabela com a data.

---

## 11. Segurança do chat (pendente)

O chat é TCP puro: sem criptografia e sem autenticação. Qualquer aparelho na mesma rede que saiba IP e
porta consegue conectar, e o conteúdo trafega em texto claro. Para uso doméstico numa rede controlada,
é aceitável.

Melhorias possíveis, em ordem de custo:

1. **Token de pareamento.** Os dois lados digitam a mesma senha no início, e a conexão só segue se bater.
   Barra conexões de estranhos, mas não protege o conteúdo.
2. **TLS com certificado autoassinado**, se for preciso proteger o conteúdo.

Não implementar sem decisão do usuário.

---

## 12. Como retomar (para o agente)

1. Ler este documento e `README.md`.
2. As etapas 0 a 4 estão aplicadas e aceitas. A limpeza estrutural da etapa 5 está aplicada.
3. Validar no aparelho, após recarregar o Quickshell, o teclado do Menu/Configurações e os caminhos dos helpers.
4. Continuar a partir do código atual; não reiniciar pelas etapas 0 a 4.
5. Registrar as verificações feitas e as validações que ainda dependem do usuário.

Antes de criar qualquer módulo, aplicar os critérios da seção 2.2 e a lista da seção 3.1. Se o módulo não
resolve um problema registrado na seção 2, não criar.

Antes de qualquer etapa que mude comportamento visível, perguntar ao usuário se ele aprova.

---

## 13. Decisões em aberto

1. O projeto vai para um repositório git, ou o controle de versão continua por zip?
2. `askpass.sh`: resolvido — removido de `phone/` por não ter referência ativa; o helper independente do Topbar permanece.
3. `settings`: resolvido — Settings permanece em `system/settings/`, com o popup próprio no mesmo módulo.
4. `SystemStatus` no núcleo e `SystemInfo` como app: resolvido — status no núcleo; Informações como app.
5. Trazer o conteúdo do `modularizaPhone.md` (raiz do projeto, fora do zip) para mesclar.
