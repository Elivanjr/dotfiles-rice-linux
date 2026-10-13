// AiSidebar.qml — barra lateral para conversar com modelos do Ollama
//
// Abre no canto esquerdo, sob a topbar. Fala com a API local do Ollama
// (http://127.0.0.1:11434) usando `curl` em streaming (/api/chat, NDJSON), então
// a resposta vai aparecendo token por token. A lista de modelos vem de /api/tags
// e é atualizada toda vez que o painel abre.
//
// Uso:
//   - Enter envia, Shift+Enter quebra linha, Esc fecha
//   - botão do modelo (cabeçalho) troca de modelo; "+" começa outra conversa
//   - alfinete: fixa o painel (não fecha ao clicar fora e deixa o resto da tela
//     clicável); desafixado, ele se comporta como o QuickSettings
//   - durante a resposta, o botão de enviar vira "parar"
//   - as respostas são renderizadas como Markdown e dá pra selecionar/copiar
//   - anexos (até 6 por mensagem): botão de clipe (abre o zenity), botão de colar
//     (imagem da área de transferência, via wl-paste), Ctrl+V no campo de texto, ou
//     arrastar arquivos pro painel. Imagens exigem modelo com visão (ex.: qwen2.5vl)
//     e são reduzidas pra 1280 px (ImageMagick) antes do envio. Arquivos de texto e
//     código (qualquer coisa que não seja binário, até 60 KB) vão como contexto.
//   - código nas respostas aparece em blocos próprios, com linguagem, realce de
//     sintaxe nas cores do tema e botão de copiar; o ↻ gera a resposta de novo
//   - quando a resposta termina, dispara uma notificação (notify-send); veja
//     notifyMode abaixo
//
// Usa scripts/ai/ai-chat.sh e scripts/ai/ai-attach.sh para chat e anexos.
//
// Controlado de fora por panelOpen / closeRequested(), igual aos outros painéis.
// A conversa vive na memória do shell: recarregar o Quickshell apaga o histórico.
//
// Cores: Colors.qml (matugen).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../theme"

PanelWindow {
  id: ai

  required property var screenRef
  screen: screenRef

  property bool panelOpen: false
  property bool atBottom: false     // true no modo Windows 10
  property int topInset: 51         // altura da topbar
  property int bottomInset: 46      // altura da WinBar + folga
  property string nerdFont: "JetBrainsMono NF"
  property int moduleRadius: 20     // vem do shell.qml (root.moduleRadius)

  // ---------- configuração ----------
  property string baseUrl: "http://127.0.0.1:11434"
  property string systemPrompt: ""  // vazio = usa o SYSTEM do próprio modelo (Modelfile)
  property int panelWidth: 440
  property bool pinned: false

  // tamanho do contexto pedido ao Ollama (0 = deixa o padrão do modelo). Sem isso o
  // Ollama costuma usar só 4096 tokens e corta o começo de arquivos grandes sem avisar.
  property int numCtx: 8192

  // notificação ao terminar a resposta:
  //   "auto"   = só se você provavelmente não está olhando (painel fechado ou fixado)
  //   "always" = sempre; "never" = nunca
  property string notifyMode: "auto"

  // scripts que conversam com o Ollama e preparam anexos
  property string scriptDir: Quickshell.env("HOME") + "/.config/quickshell/topbar/scripts/ai"

  // seletor de arquivos do botão de imagem: precisa imprimir um caminho por linha
  property var pickCmd: [
    "zenity", "--file-selection", "--multiple", "--separator=\n",
    "--title=Anexar arquivos",
    "--file-filter=Todos os arquivos | *",
    "--file-filter=Imagens | *.png *.jpg *.jpeg *.webp *.gif *.bmp"
  ]

  signal closeRequested()

  visible: panelOpen && !picking   // some enquanto o seletor de arquivos está aberto
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  // desafixado: camada transparente de tela cheia (clique fora fecha);
  // fixado: só uma faixa na esquerda, e o mask deixa o resto clicável
  anchors {
    top: true
    bottom: true
    left: true
    right: !ai.pinned
  }

  implicitWidth: ai.pinned ? ai.panelWidth + 16 : 0

  mask: ai.pinned ? pinRegion : null

  Region {
    id: pinRegion

    item: card
  }

  WlrLayershell.layer: ai.pinned ? WlrLayer.Top : WlrLayer.Overlay
  WlrLayershell.keyboardFocus: !ai.panelOpen
    ? WlrKeyboardFocus.None
    : (ai.pinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
  WlrLayershell.namespace: "quickshell:ai"

  // ================================================================
  // CORES — MATUGEN
  // ================================================================

  readonly property color cBg: Colors.md3.surface_container
  readonly property color cItem: Colors.md3.surface_container_high
  readonly property color cItemHi: Colors.md3.surface_container_highest
  readonly property color cText: Colors.md3.source_color
  readonly property color cMuted: Colors.md3.outline
  readonly property color cLine: Colors.md3.outline_variant
  readonly property color cAccent: Colors.md3.primary
  readonly property color cOnAccent: Colors.md3.on_primary
  readonly property color cError: Colors.md3.error
  readonly property color cBody: Colors.md3.on_surface   // texto das mensagens

  // realce de sintaxe: o Colors.md3 só tem um accent, então as outras cores saem
  // dele girando o matiz (combinam com qualquer wallpaper) e ajustando o brilho
  // pra dar contraste no modo escuro ou no claro
  readonly property bool darkUi: ai.cBg.hslLightness < 0.5

  function synColor(shift) {
    const h = ai.cAccent.hslHue < 0 ? 0 : ai.cAccent.hslHue;
    const s = Math.max(0.45, Math.min(0.85, ai.cAccent.hslSaturation));

    return Qt.hsla((h + shift) % 1, s, ai.darkUi ? 0.74 : 0.34, 1);
  }

  readonly property color cSynKw: ai.synColor(0)
  readonly property color cSynStr: ai.synColor(0.33)
  readonly property color cSynNum: ai.synColor(0.58)

  // ================================================================
  // ESTADO
  // ================================================================

  property string model: ""
  property var models: []
  property bool serverUp: true
  property bool busy: false
  property bool stopping: false
  property bool pickerOpen: false
  property bool stick: true           // true = acompanha o fim da conversa
  property bool autoScrolling: false
  property string notice: ""          // erro vindo do Ollama / do curl
  property string pending: ""         // tokens recebidos que ainda não entraram na tela
  property bool visionOk: true        // o modelo atual aceita imagens?
  property bool capsDirty: false
  property bool picking: false        // seletor de arquivos aberto
  property var attachQueue: []        // [{src, explicit}] esperando processamento
  property bool attachExplicit: false // o job atual veio de um clique (avisa se falhar)
  property real slide: 1              // 0..1, animação de entrada do painel

  readonly property string banner: !ai.serverUp
    ? "O Ollama não respondeu em " + ai.baseUrl + ". Ele está rodando? Tente `ollama serve` ou `systemctl start ollama`."
    : ai.notice

  ListModel {
    id: chatModel
  }

  // imagens anexadas à mensagem que ainda não foi enviada
  ListModel {
    id: attachments
  }

  onModelChanged: ai.refreshCaps()

  NumberAnimation {
    id: slideAnim

    target: ai
    property: "slide"
    from: 0
    to: 1
    duration: 190
    easing.type: Easing.OutCubic
  }

  onPanelOpenChanged: {
    if (ai.panelOpen) {
      ai.pickerOpen = false;

      if (!tagsProc.running) {
        tagsProc.running = true;
      }

      slideAnim.restart();
      Qt.callLater(() => input.forceActiveFocus());
      Qt.callLater(ai.scrollEnd);
    }
  }

  // ================================================================
  // LÓGICA
  // ================================================================

  function scrollEnd() {
    ai.autoScrolling = true;
    flick.contentY = Math.max(0, flick.contentHeight - flick.height);
    ai.autoScrolling = false;
    ai.stick = true;
  }

  // histórico enviado ao modelo: sem o balão vazio da resposta que vai chegar,
  // limitado em número de mensagens e em caracteres (o JSON vai como argumento
  // do curl, que tem teto de ~128 KB)
  function buildHistory() {
    const LIMIT = 24000;
    const msgs = [];
    const n = chatModel.count - 1;

    for (let i = 0; i < n; i++) {
      const m = chatModel.get(i);
      const c = m.content.length > LIMIT ? m.content.slice(0, LIMIT) : m.content;

      // arquivos de texto: o conteúdo entra depois do texto, num bloco com cerca de
      // 4 crases (aguenta arquivos que têm ``` dentro); ai-chat.sh troca o marcador
      let withFiles = c;

      if (m.files && m.files !== "") {
        for (const f of JSON.parse(m.files)) {
          withFiles += "\n\n[Arquivo: " + f.name + (f.trunc ? " (truncado)" : "")
            + "]\n````\n@@TXT:" + f.path + "@@\n````";
        }
      }

      const msg = { role: m.role, content: withFiles };

      if (m.images && m.images !== "") {
        msg.images = JSON.parse(m.images).map(p => "@@IMG:" + p + "@@");
      }

      msgs.push(msg);
    }

    let total = 0;
    let start = msgs.length;

    for (let i = msgs.length - 1; i >= 0 && msgs.length - i <= 40; i--) {
      total += msgs[i].content.length;

      if (total > LIMIT && start < msgs.length) {
        break;
      }

      start = i;
    }

    const out = [];

    if (ai.systemPrompt !== "") {
      out.push({ role: "system", content: ai.systemPrompt });
    }

    return out.concat(msgs.slice(start));
  }

  function submit() {
    const typed = input.text.trim();
    const imgs = [];
    const files = [];

    for (let i = 0; i < attachments.count; i++) {
      const at = attachments.get(i);

      if (at.kind === "image") {
        imgs.push(at.path);
      } else {
        files.push({ path: at.path, name: at.name, trunc: at.trunc !== "" });
      }
    }

    if ((typed === "" && imgs.length === 0 && files.length === 0) || ai.busy || ai.model === "" || !ai.serverUp) {
      return;
    }

    if (attachProc.running || ai.attachQueue.length > 0) {
      ai.notice = "Espera a imagem terminar de ser processada.";
      return;
    }

    if (imgs.length > 0 && !ai.visionOk) {
      ai.notice = "O modelo " + ai.model + " não aceita imagens. Escolha um com visão (como qwen2.5vl).";
      return;
    }

    let t = typed;

    if (t === "") {
      if (imgs.length === 0) {
        t = files.length > 1 ? "Analise estes arquivos." : "Analise este arquivo.";
      } else {
        t = imgs.length > 1 ? "Descreva estas imagens." : "Descreva esta imagem.";
      }
    }

    ai.notice = "";
    ai.pickerOpen = false;

    chatModel.append({
      role: "user",
      content: t,
      stats: "",
      images: imgs.length > 0 ? JSON.stringify(imgs) : "",
      files: files.length > 0 ? JSON.stringify(files) : ""
    });
    chatModel.append({ role: "assistant", content: "", stats: "", images: "", files: "" });

    attachments.clear();
    input.text = "";

    ai.startRequest();
  }

  // dispara o pedido com o histórico atual; o último item do modelo é sempre o
  // balão vazio da resposta que vai chegar (também usado pra gerar de novo)
  function startRequest() {
    const body = {
      model: ai.model,
      messages: ai.buildHistory(),
      stream: true
    };

    if (ai.numCtx > 0) {
      body.options = { num_ctx: ai.numCtx };
    }

    ai.pending = "";
    ai.stopping = false;
    ai.busy = true;

    // ai-chat.sh troca os @@IMG:...@@ pelo base64 e faz o streaming com o curl
    chatProc.command = ["bash", ai.scriptDir + "/ai-chat.sh", JSON.stringify(body), ai.baseUrl];
    chatProc.running = true;

    ai.scrollEnd();
  }

  function stop() {
    if (ai.busy) {
      ai.stopping = true;
      chatProc.running = false;
    }
  }

  function newChat() {
    ai.stop();
    flushTimer.stop();
    ai.pending = "";
    ai.notice = "";

    // apaga as imagens temporárias da conversa e dos anexos pendentes
    const paths = [];

    for (let i = 0; i < chatModel.count; i++) {
      const im = chatModel.get(i).images;

      if (im && im !== "") {
        JSON.parse(im).forEach(p => paths.push(p));
      }

      const fs = chatModel.get(i).files;

      if (fs && fs !== "") {
        JSON.parse(fs).forEach(f => paths.push(f.path));
      }
    }

    for (let i = 0; i < attachments.count; i++) {
      paths.push(attachments.get(i).path);
    }

    attachments.clear();
    chatModel.clear();

    if (paths.length > 0) {
      Quickshell.execDetached(["rm", "-f"].concat(paths));
    }
  }

  // joga os tokens acumulados no último balão
  function flush() {
    if (chatModel.count === 0 || ai.pending === "") {
      return;
    }

    const i = chatModel.count - 1;

    chatModel.setProperty(i, "content", chatModel.get(i).content + ai.pending);
    ai.pending = "";
  }

  // uma linha do NDJSON do /api/chat
  function onChatLine(line) {
    if (line.trim() === "") {
      return;
    }

    let o;

    try {
      o = JSON.parse(line);
    } catch (e) {
      return;
    }

    if (o.error) {
      ai.notice = String(o.error);
      return;
    }

    if (o.message && o.message.content) {
      ai.pending += o.message.content;

      if (!flushTimer.running) {
        flushTimer.start();
      }
    }

    if (o.done) {
      ai.flush();

      if (o.eval_count && o.eval_duration && chatModel.count > 0) {
        const tps = o.eval_count / (o.eval_duration / 1e9);

        chatModel.setProperty(chatModel.count - 1, "stats",
          o.eval_count + " tokens · " + tps.toFixed(1) + " tok/s");
      }
    }
  }

  function onChatExit(code) {
    flushTimer.stop();
    ai.flush();
    ai.busy = false;

    const last = chatModel.count - 1;
    const empty = last >= 0
      && chatModel.get(last).role === "assistant"
      && chatModel.get(last).content === "";

    if (!ai.stopping && code !== 0 && ai.notice === "") {
      if (code === 7) {
        ai.serverUp = false;
      } else {
        ai.notice = "O curl terminou com erro (código " + code + ").";
      }
    } else if (!ai.stopping && empty && ai.notice === "") {
      ai.notice = "O modelo não devolveu nenhuma resposta.";
    }

    // balão vazio (parou antes do primeiro token, ou deu erro): remove
    const ok = !ai.stopping && code === 0 && ai.notice === "" && !empty;

    if (empty) {
      chatModel.remove(last);
    }

    ai.stopping = false;

    if (ok) {
      ai.notifyDone();
    }
  }

  function notifyDone() {
    if (ai.notifyMode === "never") {
      return;
    }

    // "auto": painel aberto e desafixado = você está olhando a resposta chegar
    if (ai.notifyMode === "auto" && ai.panelOpen && !ai.pinned) {
      return;
    }

    const last = chatModel.count - 1;

    if (last < 0 || chatModel.get(last).role !== "assistant") {
      return;
    }

    let txt = chatModel.get(last).content
      .replace(/(`{3,}|~{3,})[\s\S]*?(\1|$)/g, " (código) ")
      .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
      .replace(/[#*_`>~\[\]]/g, "")
      .replace(/\s+/g, " ")
      .trim();

    if (txt.length > 140) {
      txt = txt.slice(0, 137) + "…";
    }

    Quickshell.execDetached([
      "notify-send", "-a", "Ollama", "-t", "8000",
      ai.model + " respondeu",
      txt !== "" ? txt : "A resposta está pronta."
    ]);
  }

  // gera a última resposta de novo (descarta a atual e refaz o pedido)
  function regenerate() {
    const last = chatModel.count - 1;

    if (ai.busy || last < 1 || chatModel.get(last).role !== "assistant") {
      return;
    }

    ai.notice = "";
    chatModel.setProperty(last, "content", "");
    chatModel.setProperty(last, "stats", "");
    ai.startRequest();
  }

  // >>> JS-LOGIC-BEGIN
  // ---------- código: separação em blocos e realce de sintaxe ----------

  // divide uma resposta em trechos {type: "text"|"code", text, lang}. Uma cerca ``` ainda
  // sem fechar (resposta chegando em streaming) vira um bloco de código aberto.
  function parseSegments(content) {
    const segs = [];
    let buf = [];
    let inCode = false;
    let lang = "";

    function pushText() {
      const t = buf.join("\n").replace(/^(\s*\n)+/, "").replace(/\s+$/, "");

      if (t !== "") {
        segs.push({ type: "text", text: t, lang: "" });
      }

      buf = [];
    }

    for (const line of content.split("\n")) {
      if (!inCode) {
        const o = /^\s*(?:`{3,}|~{3,})\s*([^\s`]*)/.exec(line);

        if (o) {
          pushText();
          inCode = true;
          lang = o[1];
        } else {
          buf.push(line);
        }
      } else if (/^\s*(?:`{3,}|~{3,})\s*$/.test(line)) {
        segs.push({ type: "code", text: buf.join("\n"), lang: lang });
        buf = [];
        inCode = false;
        lang = "";
      } else {
        buf.push(line);
      }
    }

    if (inCode) {
      segs.push({ type: "code", text: buf.join("\n"), lang: lang });
    } else {
      pushText();
    }

    return segs;
  }

  // mensagens do usuário não são Markdown: viram um trecho de texto puro
  function userSegs(content) {
    return content === "" ? [] : [{ type: "plain", text: content, lang: "" }];
  }

  function escHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  // código -> HTML pro TextEdit (RichText). Reconhece comentários, strings, números e
  // palavras-chave de algumas famílias de linguagem; o resto fica sem cor. O texto
  // do código nunca é alterado: só ganha <span> em volta (e & < > escapados).
  function highlight(code, lang) {
    const FAMILY = {
      js: "js", javascript: "js", jsx: "js", ts: "js", typescript: "js", tsx: "js",
      mjs: "js", cjs: "js", qml: "js", json: "json", jsonc: "json",
      py: "python", python: "python",
      sh: "bash", bash: "bash", zsh: "bash", shell: "bash", fish: "bash", console: "bash",
      c: "c", h: "c", cpp: "c", "c++": "c", hpp: "c", cc: "c", java: "c", kotlin: "c",
      kt: "c", cs: "c", csharp: "c", swift: "c", php: "c", dart: "c", scala: "c",
      go: "go", golang: "go", rs: "rust", rust: "rust", sql: "sql", lua: "lua",
      yaml: "conf", yml: "conf", toml: "conf", ini: "conf", conf: "conf",
      dockerfile: "conf", makefile: "conf", make: "conf", nix: "conf",
      rb: "ruby", ruby: "ruby"
    };

    const KW = {
      js: "const let var function return if else for while do switch case break continue new class extends import from export default async await try catch finally throw typeof instanceof in of this super static get set yield interface type enum implements public private protected readonly as void delete property signal required component",
      json: "",
      python: "def class return if elif else for while in not and or is import from as with try except finally raise pass break continue lambda yield global nonlocal async await del assert self",
      bash: "if then else elif fi for while do done case esac in function return exit export local readonly source echo cd set unset",
      c: "int char float double long short unsigned signed void struct union enum typedef static const extern inline return if else for while do switch case break continue goto sizeof new delete class public private protected virtual namespace using template typename include define this final override try catch throw import package interface extends implements abstract boolean byte string var val fun let func",
      go: "func package import var const type struct interface map chan return if else for range switch case default break continue go defer select fallthrough",
      rust: "fn let mut pub struct enum impl trait use mod crate self super return if else for while loop match break continue as in where move ref static const unsafe async await dyn type",
      sql: "select from where insert into values update set delete create table drop alter join left right inner outer on group by order having limit as and or not null primary key distinct union index",
      lua: "local function end if then else elseif for while do repeat until return break in and or not",
      conf: "",
      ruby: "def class module end if elsif else unless while until for in do begin rescue ensure return yield require include self nil then case when and or not"
    };

    const LIT = { true: 1, false: 1, null: 1, nil: 1, None: 1, True: 1, False: 1, undefined: 1, NULL: 1, NaN: 1 };

    const open = '<p style="white-space: pre-wrap; margin: 0;">';
    const fam = FAMILY[(lang || "").toLowerCase()] || "";

    if (fam === "") {
      return open + escHtml(code) + "</p>";
    }

    const cKw = String(ai.cSynKw);
    const cStr = String(ai.cSynStr);
    const cNum = String(ai.cSynNum);
    const cCom = String(ai.cMuted);

    const kw = {};

    KW[fam].split(" ").forEach(w => {
      if (w !== "") {
        kw[w] = 1;
      }
    });

    let rx;

    if (fam === "python" || fam === "bash" || fam === "conf" || fam === "ruby") {
      rx = /#[^\n]*|"""[\s\S]*?(?:"""|$)|'''[\s\S]*?(?:'''|$)|"(?:\\.|[^"\\\n])*"?|'(?:\\.|[^'\\\n])*'?|\b0x[0-9a-fA-F]+\b|\b\d[\d_]*\.?\d*(?:[eE][+-]?\d+)?\b|[A-Za-z_]\w*/g;
    } else if (fam === "sql" || fam === "lua") {
      rx = /--[^\n]*|\/\*[\s\S]*?(?:\*\/|$)|"(?:\\.|[^"\\\n])*"?|'(?:\\.|[^'\\\n])*'?|\b\d[\d_]*\.?\d*\b|[A-Za-z_]\w*/g;
    } else if (fam === "rust") {
      rx = /\/\/[^\n]*|\/\*[\s\S]*?(?:\*\/|$)|"(?:\\.|[^"\\\n])*"?|'(?:\\.|[^'\\\n])'|\b0x[0-9a-fA-F]+\b|\b\d[\d_]*\.?\d*(?:[eE][+-]?\d+)?\b|[A-Za-z_]\w*/g;
    } else {
      rx = /\/\/[^\n]*|\/\*[\s\S]*?(?:\*\/|$)|"(?:\\.|[^"\\\n])*"?|'(?:\\.|[^'\\\n])*'?|`(?:\\.|[^`\\])*`?|\b0x[0-9a-fA-F]+\b|\b\d[\d_]*\.?\d*(?:[eE][+-]?\d+)?\b|[A-Za-z_$][\w$]*/g;
    }

    let out = "";
    let last = 0;
    let m;

    while ((m = rx.exec(code)) !== null) {
      const t = m[0];

      if (t === "") {
        rx.lastIndex++;
        continue;
      }

      const c0 = t.charAt(0);
      let col = "";
      let italic = false;

      if (c0 === "#" || t.indexOf("//") === 0 || t.indexOf("/*") === 0 || t.indexOf("--") === 0) {
        col = cCom;
        italic = true;
      } else if (c0 === '"' || c0 === "'" || c0 === "`") {
        col = cStr;
      } else if (c0 >= "0" && c0 <= "9") {
        col = cNum;
      } else {
        const key = fam === "sql" ? t.toLowerCase() : t;

        if (Object.prototype.hasOwnProperty.call(kw, key)) {
          col = cKw;
        } else if (Object.prototype.hasOwnProperty.call(LIT, t)) {
          col = cNum;
        }
      }

      out += escHtml(code.slice(last, m.index));
      out += col === ""
        ? escHtml(t)
        : '<span style="color:' + col + (italic ? ";font-style:italic" : "") + '">' + escHtml(t) + "</span>";
      last = m.index + t.length;
    }

    return open + out + escHtml(code.slice(last)) + "</p>";
  }
  // <<< JS-LOGIC-END

  // ---------- imagens ----------

  // pergunta ao Ollama se o modelo atual tem a capacidade "vision"
  function refreshCaps() {
    if (ai.model === "") {
      ai.visionOk = false;
      return;
    }

    if (showProc.running) {
      ai.capsDirty = true;
      return;
    }

    ai.capsDirty = false;
    showProc.command = [
      "curl", "-s", "--max-time", "5", "-X", "POST",
      ai.baseUrl + "/api/show",
      "-d", JSON.stringify({ model: ai.model })
    ];
    showProc.running = true;
  }

  function parseShow(text) {
    try {
      const j = JSON.parse(text);

      // Ollama antigo não manda "capabilities": nesse caso deixa tentar
      ai.visionOk = Array.isArray(j.capabilities)
        ? j.capabilities.indexOf("vision") >= 0
        : true;
    } catch (e) {
      ai.visionOk = true;
    }

    if (ai.capsDirty) {
      ai.refreshCaps();
    }
  }

  function urlToPath(u) {
    let s = String(u).trim();

    if (s.indexOf("file://") === 0) {
      s = decodeURIComponent(s.slice(7));
    }

    return s;
  }

  // src = caminho de arquivo, ou "-clip" pra imagem da área de transferência
  function attach(src, explicit) {
    if (src === "") {
      return;
    }

    const inFlight = attachments.count + ai.attachQueue.length + (attachProc.running ? 1 : 0);

    if (inFlight >= 6) {
      if (explicit) {
        ai.notice = "Máximo de 6 anexos por mensagem.";
      }

      return;
    }

    ai.attachQueue = ai.attachQueue.concat([{ src: src, explicit: explicit }]);
    ai.nextAttach();
  }

  function attachClip(explicit) {
    ai.attach("-clip", explicit);
  }

  function nextAttach() {
    if (attachProc.running || ai.attachQueue.length === 0) {
      return;
    }

    const job = ai.attachQueue[0];

    ai.attachQueue = ai.attachQueue.slice(1);
    ai.attachExplicit = job.explicit;
    attachProc.command = ["bash", ai.scriptDir + "/ai-attach.sh", job.src];
    attachProc.running = true;
  }

  // uma linha do ai-attach.sh: "image<TAB>caminho" ou "text<TAB>caminho<TAB>nome<TAB>trunc"
  function addAttachment(line) {
    const f = line.replace(/\r?\n$/, "").split("\t");

    if (f.length < 2 || f[1] === "") {
      return;
    }

    if (f[0] === "image") {
      if (!ai.visionOk) {
        // imagem num modelo sem visão: descarta (só avisa se foi um clique de propósito)
        Quickshell.execDetached(["rm", "-f", f[1]]);

        if (ai.attachExplicit) {
          ai.notice = "O modelo " + ai.model + " não aceita imagens. Escolha um com visão (como qwen2.5vl).";
        }

        return;
      }

      attachments.append({ kind: "image", path: f[1], name: "", trunc: "" });
    } else if (f[0] === "text") {
      attachments.append({ kind: "text", path: f[1], name: f[2] || "arquivo", trunc: f[3] || "" });
    }
  }

  function onAttachExit(code) {
    if (code === 3 && ai.attachExplicit) {
      ai.notice = "Não há imagem na área de transferência (o wl-paste está instalado?).";
    } else if (code === 4) {
      ai.notice = "Não consegui ler esse arquivo.";
    } else if (code === 5) {
      ai.notice = "Não consegui converter a imagem. Isso é mesmo uma imagem?";
    } else if (code === 6) {
      ai.notice = "Esse tipo de arquivo não dá pra anexar (só imagem, texto e código).";
    } else if (code !== 0 && code !== 3) {
      ai.notice = "Falha ao anexar a imagem (código " + code + ").";
    }

    Qt.callLater(ai.nextAttach);
  }

  function removeAttachment(i) {
    const p = attachments.get(i).path;

    attachments.remove(i);
    Quickshell.execDetached(["rm", "-f", p]);
  }

  function pickFiles() {
    // a barra some enquanto o seletor está aberto (ela ficaria por cima dele)
    ai.picking = true;
    pickProc.running = true;
    pickGuard.start();
  }

  // resposta do /api/tags
  function parseTags(text) {
    try {
      const j = JSON.parse(text);
      const names = (j.models || []).map(m => m.name);

      ai.models = names;
      ai.serverUp = true;

      if (names.length === 0) {
        ai.model = "";
      } else if (names.indexOf(ai.model) < 0) {
        ai.model = names[0];
      }
    } catch (e) {
      ai.serverUp = false;
    }
  }

  // ================================================================
  // PROCESSOS
  // ================================================================

  Process {
    id: tagsProc

    command: ["curl", "-s", "--max-time", "3", ai.baseUrl + "/api/tags"]

    stdout: StdioCollector {
      onStreamFinished: ai.parseTags(this.text)
    }
  }

  Process {
    id: chatProc

    stdout: SplitParser {
      onRead: (data) => ai.onChatLine(data)
    }

    onExited: (code, status) => ai.onChatExit(code)
  }

  Process {
    id: showProc

    stdout: StdioCollector {
      onStreamFinished: ai.parseShow(this.text)
    }
  }

  Process {
    id: attachProc

    stdout: SplitParser {
      onRead: (data) => ai.addAttachment(data)
    }

    onExited: (code, status) => ai.onAttachExit(code)
  }

  Process {
    id: pickProc

    command: ai.pickCmd

    stdout: SplitParser {
      onRead: (data) => ai.attach(ai.urlToPath(data), true)
    }

    onRunningChanged: {
      if (!pickProc.running) {
        ai.picking = false;
      }
    }

    onExited: (code, status) => {
      // 0 = escolheu, 1 = cancelou; qualquer outra coisa é o seletor quebrado
      if (code !== 0 && code !== 1) {
        ai.notice = "O seletor de arquivos (" + ai.pickCmd[0] + ") falhou. Ele está instalado?";
      }
    }
  }

  // se o seletor nem chegou a abrir, a barra não pode ficar escondida pra sempre
  Timer {
    id: pickGuard

    interval: 1500

    onTriggered: {
      if (!pickProc.running) {
        ai.picking = false;
      }
    }
  }

  // junta tokens em lotes: reprocessar Markdown a cada token pesa à toa
  Timer {
    id: flushTimer

    interval: 60
    repeat: true

    onTriggered: ai.flush()
  }

  // ================================================================
  // COMPONENTES
  // ================================================================

  component Glyph: Text {
    font.family: ai.nerdFont
    font.pixelSize: 16
    color: ai.cText
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  component Label: Text {
    font.family: ai.nerdFont
    font.pixelSize: 12
    color: ai.cText
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
  }

  component RoundBtn: Rectangle {
    id: rb

    property string glyph: ""
    property bool active: false
    property bool primary: false

    signal clicked()

    implicitWidth: 32
    implicitHeight: 32
    radius: width / 2
    color: rb.primary || rb.active
      ? (rbArea.containsMouse ? Qt.lighter(ai.cAccent, 1.1) : ai.cAccent)
      : (rbArea.containsMouse ? ai.cItemHi : ai.cItem)

    Glyph {
      anchors.centerIn: parent
      text: rb.glyph
      color: (rb.primary || rb.active) ? ai.cOnAccent : ai.cText
      font.pixelSize: 13
    }

    MouseArea {
      id: rbArea

      anchors.fill: parent
      hoverEnabled: true
      onClicked: rb.clicked()
    }
  }

  // ================================================================
  // JANELA
  // ================================================================

  Item {
    id: rootItem

    anchors.fill: parent
    focus: true

    Keys.onEscapePressed: ai.closeRequested()

    // clique fora do cartão fecha (só no modo desafixado)
    MouseArea {
      anchors.fill: parent
      enabled: !ai.pinned
      onClicked: ai.closeRequested()
    }

    Rectangle {
      id: card

      width: ai.panelWidth
      x: 8 - (1 - ai.slide) * 36
      y: ai.atBottom ? 8 : ai.topInset
      opacity: ai.slide
      height: parent.height - y - (ai.atBottom ? ai.bottomInset : 8)

      radius: Math.min(ai.moduleRadius, 28)
      color: ai.cBg
      border.width: 1
      border.color: ai.cLine
      clip: true

      // engole cliques dentro do cartão
      MouseArea {
        anchors.fill: parent
      }

      // arrastar imagens de um gerenciador de arquivos pro painel
      DropArea {
        anchors.fill: parent

        onDropped: (drop) => {
          if (drop.hasUrls) {
            for (const u of drop.urls) {
              ai.attach(ai.urlToPath(u), true);
            }

            drop.accept();
          }
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ---------- cabeçalho ----------
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Glyph {
            text: "\u{F06A9}" // robot
            color: ai.cAccent
            font.pixelSize: 20
          }

          // seletor de modelo
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 32
            radius: height / 2
            color: modelArea.containsMouse ? ai.cItemHi : ai.cItem

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 14
              anchors.rightMargin: 12
              spacing: 8

              Label {
                text: ai.model !== "" ? ai.model : "sem modelo"
                font.bold: true
                Layout.fillWidth: true
              }

              Glyph {
                visible: ai.visionOk && ai.model !== ""
                text: "\uf06e" // eye: o modelo enxerga imagens
                color: ai.cMuted
                font.pixelSize: 11
              }

              Glyph {
                text: ai.pickerOpen ? "\uf077" : "\uf078" // chevron up / down
                color: ai.cMuted
                font.pixelSize: 10
              }
            }

            MouseArea {
              id: modelArea

              anchors.fill: parent
              hoverEnabled: true
              onClicked: ai.pickerOpen = !ai.pickerOpen
            }
          }

          RoundBtn {
            glyph: "\uf067" // plus: nova conversa
            onClicked: ai.newChat()
          }

          RoundBtn {
            glyph: "\uf08d" // thumb-tack: fixar
            active: ai.pinned
            onClicked: ai.pinned = !ai.pinned
          }

          RoundBtn {
            glyph: "\uf00d" // times: fechar
            onClicked: ai.closeRequested()
          }
        }

        // ---------- lista de modelos (inline) ----------
        Rectangle {
          visible: ai.pickerOpen
          Layout.fillWidth: true
          implicitHeight: Math.min(200, pickCol.implicitHeight + 12)
          radius: 16
          color: ai.cItem
          clip: true

          Flickable {
            anchors.fill: parent
            anchors.margins: 6
            contentWidth: width
            contentHeight: pickCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
              id: pickCol

              width: parent.width
              spacing: 2

              Repeater {
                model: ai.models

                delegate: Rectangle {
                  id: opt

                  required property string modelData

                  width: pickCol.width
                  height: 32
                  radius: 12
                  color: opt.modelData === ai.model
                    ? ai.cAccent
                    : (optArea.containsMouse ? ai.cItemHi : "transparent")

                  Label {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    text: opt.modelData
                    color: opt.modelData === ai.model ? ai.cOnAccent : ai.cText
                  }

                  MouseArea {
                    id: optArea

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                      ai.model = opt.modelData;
                      ai.pickerOpen = false;
                    }
                  }
                }
              }

              Label {
                visible: ai.models.length === 0
                width: pickCol.width
                height: 32
                text: "Nenhum modelo instalado (ollama pull ...)"
                color: ai.cMuted
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }
        }

        // ---------- aviso / erro ----------
        Rectangle {
          visible: ai.banner !== ""
          Layout.fillWidth: true
          implicitHeight: bannerRow.implicitHeight + 16
          radius: 14
          color: ai.cItem
          border.width: 1
          border.color: ai.cError

          RowLayout {
            id: bannerRow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 8

            Label {
              text: ai.banner
              color: ai.cError
              font.pixelSize: 11
              wrapMode: Text.Wrap
              elide: Text.ElideNone
              Layout.fillWidth: true
            }

            RoundBtn {
              glyph: "\uf021" // refresh: tenta de novo / some com o aviso
              implicitWidth: 28
              implicitHeight: 28

              onClicked: {
                ai.notice = "";

                if (!tagsProc.running) {
                  tagsProc.running = true;
                }
              }
            }
          }
        }

        // ---------- conversa ----------
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true

          // estado vazio
          Column {
            visible: chatModel.count === 0
            anchors.centerIn: parent
            spacing: 8

            Glyph {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "\u{F06A9}"
              color: ai.cItemHi
              font.pixelSize: 56
            }

            Label {
              anchors.horizontalCenter: parent.horizontalCenter
              text: ai.model !== ""
                ? "Converse com " + ai.model
                  + (ai.visionOk ? " (com visão)" : "")
                : "Nenhum modelo disponível"
              color: ai.cMuted
            }
          }

          Flickable {
            id: flick

            anchors.fill: parent
            contentWidth: width
            contentHeight: msgCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            // acompanha o fim enquanto a resposta cresce; se você rolar pra cima, solta
            onContentHeightChanged: {
              if (ai.stick) {
                ai.scrollEnd();
              }
            }

            onContentYChanged: {
              if (!ai.autoScrolling) {
                ai.stick = (flick.contentY + flick.height >= flick.contentHeight - 8);
              }
            }

            Column {
              id: msgCol

              width: flick.width - 8
              spacing: 10

              Repeater {
                model: chatModel

                delegate: Item {
                  id: row

                  required property int index
                  required property string role
                  required property string content
                  required property string stats
                  required property string images
                  required property string files

                  readonly property var imgList: row.images !== "" ? JSON.parse(row.images) : []
                  readonly property var fileList: row.files !== "" ? JSON.parse(row.files) : []
                  readonly property real thumbsW: row.imgList.length > 0 ? row.imgList.length * 78 - 6 : 0
                  readonly property real chipsW: row.fileList.length > 0 ? 190 : 0

                  readonly property bool isUser: row.role === "user"
                  readonly property bool isLast: row.index === chatModel.count - 1
                  readonly property bool streaming: ai.busy && row.isLast

                  // trechos da mensagem: texto (Markdown) e blocos de código
                  readonly property var segs: row.isUser ? ai.userSegs(row.content) : ai.parseSegments(row.content)

                  width: msgCol.width
                  height: bubble.height + (foot.visible ? foot.height + 4 : 0)

                  // mede o texto sem quebra, pra balão do usuário ficar do tamanho da frase
                  Text {
                    id: probe

                    visible: false
                    text: row.content
                    wrapMode: Text.NoWrap
                    font.family: ai.nerdFont
                    font.pixelSize: 13
                  }

                  // texto cru da mensagem inteira (com as cercas ```), só pra copiar
                  TextEdit {
                    id: rawCopy

                    visible: false
                    text: row.content
                  }

                  Rectangle {
                    id: bubble

                    anchors.right: row.isUser ? parent.right : undefined
                    anchors.left: row.isUser ? undefined : parent.left

                    width: row.isUser
                      ? Math.min(row.width * 0.9, Math.max(probe.implicitWidth, row.thumbsW, row.chipsW) + 28)
                      : row.width
                    height: Math.max(36, bubbleCol.height + 20)
                    radius: 16
                    color: row.isUser ? ai.cAccent : ai.cItem

                    Column {
                      id: bubbleCol

                      x: 14
                      y: 10
                      width: bubble.width - 28
                      spacing: 8

                      // miniaturas das imagens enviadas
                      Flow {
                        visible: row.imgList.length > 0
                        width: bubbleCol.width
                        spacing: 6

                        Repeater {
                          model: row.imgList

                          delegate: Image {
                            required property string modelData

                            width: 72
                            height: 72
                            source: "file://" + modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 144
                            sourceSize.height: 144
                          }
                        }
                      }

                      // arquivos de texto enviados
                      Flow {
                        visible: row.fileList.length > 0
                        width: bubbleCol.width
                        spacing: 6

                        Repeater {
                          model: row.fileList

                          delegate: Rectangle {
                            id: fileChip

                            required property var modelData

                            width: Math.min(bubbleCol.width, 190)
                            height: 30
                            radius: 10
                            color: Qt.alpha(ai.cOnAccent, 0.16)

                            Row {
                              anchors.verticalCenter: parent.verticalCenter
                              x: 10
                              width: parent.width - 20
                              spacing: 6

                              Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\uf15c" // file-text
                                color: ai.cOnAccent
                                font.pixelSize: 13
                              }

                              Label {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 22
                                text: fileChip.modelData.name
                                color: ai.cOnAccent
                                font.pixelSize: 11
                              }
                            }
                          }
                        }
                      }

                      // trechos de texto e de código
                      Repeater {
                        // só o NÚMERO de trechos é o modelo: assim os trechos já criados
                        // são atualizados no lugar (e a seleção do mouse não se perde)
                        model: row.segs.length

                        delegate: Item {
                          id: seg

                          required property int index

                          readonly property string segType: (row.segs[seg.index] || {}).type || "text"
                          readonly property string segText: (row.segs[seg.index] || {}).text || ""
                          readonly property string segLang: (row.segs[seg.index] || {}).lang || ""
                          readonly property string segHtml: seg.segType === "code"
                            ? ai.highlight(seg.segText, seg.segLang)
                            : ""

                          property bool copied: false

                          width: bubbleCol.width
                          height: seg.segType === "code" ? codeBox.height : proseText.contentHeight

                          // ---- texto ----
                          TextEdit {
                            id: proseText

                            visible: seg.segType !== "code"
                            width: parent.width
                            text: seg.segType !== "code" ? seg.segText : ""
                            textFormat: seg.segType === "plain" ? TextEdit.PlainText : TextEdit.MarkdownText
                            wrapMode: TextEdit.Wrap
                            readOnly: true
                            selectByMouse: true
                            color: row.isUser ? ai.cOnAccent : ai.cBody
                            selectionColor: row.isUser ? ai.cOnAccent : ai.cAccent
                            selectedTextColor: row.isUser ? ai.cAccent : ai.cOnAccent
                            font.family: ai.nerdFont
                            font.pixelSize: 13

                            onLinkActivated: (link) => Qt.openUrlExternally(link)
                          }

                          // ---- bloco de código ----
                          Rectangle {
                            id: codeBox

                            visible: seg.segType === "code"
                            width: parent.width
                            height: 36 + codeBody.contentHeight + 12
                            radius: 12
                            color: ai.cBg
                            border.width: 1
                            border.color: ai.cLine

                            // cabeçalho: linguagem + copiar
                            Rectangle {
                              x: 1
                              y: 1
                              width: parent.width - 2
                              height: 28
                              radius: 11
                              color: ai.cItemHi

                              // quadrado embaixo, pra só o topo ficar arredondado
                              Rectangle {
                                y: 14
                                width: parent.width
                                height: 14
                                color: parent.color
                              }

                              Label {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: seg.segLang !== "" ? seg.segLang : "código"
                                color: ai.cMuted
                                font.pixelSize: 10
                              }

                              Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: copyRow.implicitWidth + 16
                                height: 22
                                radius: 11
                                color: codeCopyArea.containsMouse ? ai.cLine : "transparent"

                                Row {
                                  id: copyRow

                                  anchors.centerIn: parent
                                  spacing: 5

                                  Glyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: seg.copied ? "\uf00c" : "\uf0c5" // check / copy
                                    color: seg.copied ? ai.cSynStr : ai.cMuted
                                    font.pixelSize: 10
                                  }

                                  Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: seg.copied ? "copiado" : "copiar"
                                    color: seg.copied ? ai.cSynStr : ai.cMuted
                                    font.pixelSize: 10
                                  }
                                }

                                MouseArea {
                                  id: codeCopyArea

                                  anchors.fill: parent
                                  hoverEnabled: true

                                  onClicked: {
                                    codeRaw.selectAll();
                                    codeRaw.copy();
                                    codeRaw.deselect();
                                    seg.copied = true;
                                    copiedTimer.restart();
                                  }
                                }
                              }
                            }

                            TextEdit {
                              id: codeBody

                              x: 12
                              y: 36
                              width: parent.width - 24
                              text: seg.segHtml
                              textFormat: TextEdit.RichText
                              wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                              readOnly: true
                              selectByMouse: true
                              color: ai.cBody
                              selectionColor: ai.cAccent
                              selectedTextColor: ai.cOnAccent
                              font.family: ai.nerdFont
                              font.pixelSize: 12
                            }
                          }

                          // código puro (sem HTML), usado só pra copiar
                          TextEdit {
                            id: codeRaw

                            visible: false
                            text: seg.segText
                          }

                          Timer {
                            id: copiedTimer

                            interval: 1500
                            onTriggered: seg.copied = false
                          }
                        }
                      }
                    }

                    Label {
                      visible: !row.isUser && row.content === "" && row.streaming
                      x: 14
                      anchors.verticalCenter: parent.verticalCenter
                      text: "pensando…"
                      color: ai.cMuted
                    }
                  }

                  // rodapé da resposta: velocidade, copiar tudo e gerar de novo
                  RowLayout {
                    id: foot

                    visible: !row.isUser && row.content !== "" && !row.streaming
                    anchors.top: bubble.bottom
                    anchors.topMargin: 4
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    spacing: 6
                    height: 22

                    Label {
                      text: row.stats
                      color: ai.cMuted
                      font.pixelSize: 10
                    }

                    Rectangle {
                      implicitWidth: 22
                      implicitHeight: 22
                      radius: 11
                      color: copyArea.containsMouse ? ai.cItemHi : "transparent"

                      Glyph {
                        anchors.centerIn: parent
                        text: "\uf0c5" // copy
                        color: ai.cMuted
                        font.pixelSize: 11
                      }

                      MouseArea {
                        id: copyArea

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                          rawCopy.selectAll();
                          rawCopy.copy();
                          rawCopy.deselect();
                        }
                      }
                    }

                    Rectangle {
                      visible: row.isLast && !ai.busy
                      implicitWidth: 22
                      implicitHeight: 22
                      radius: 11
                      color: regenArea.containsMouse ? ai.cItemHi : "transparent"

                      Glyph {
                        anchors.centerIn: parent
                        text: "\uf021" // refresh: gerar de novo
                        color: ai.cMuted
                        font.pixelSize: 11
                      }

                      MouseArea {
                        id: regenArea

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: ai.regenerate()
                      }
                    }
                  }
                }
              }
            }
          }

          // volta pro fim da conversa quando você rolou pra cima
          Rectangle {
            visible: !ai.stick && flick.contentHeight > flick.height
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            width: 32
            height: 32
            radius: 16
            color: toEndArea.containsMouse ? ai.cAccent : ai.cItemHi
            border.width: 1
            border.color: ai.cLine

            Glyph {
              anchors.centerIn: parent
              text: "\uf078" // chevron-down
              color: toEndArea.containsMouse ? ai.cOnAccent : ai.cText
              font.pixelSize: 12
            }

            MouseArea {
              id: toEndArea

              anchors.fill: parent
              hoverEnabled: true
              onClicked: ai.scrollEnd()
            }
          }

          // barra de rolagem fininha
          Rectangle {
            visible: flick.contentHeight > flick.height
            x: parent.width - 4
            y: flick.visibleArea.yPosition * flick.height
            width: 3
            height: Math.max(24, flick.visibleArea.heightRatio * flick.height)
            radius: 2
            color: ai.cMuted
            opacity: 0.5
          }
        }

        // ---------- anexos pendentes ----------
        Flow {
          visible: attachments.count > 0 || attachProc.running
          Layout.fillWidth: true
          spacing: 8

          Repeater {
            model: attachments

            delegate: Rectangle {
              id: th

              required property int index
              required property string kind
              required property string path
              required property string name
              required property string trunc

              width: th.kind === "text" ? 160 : 56
              height: 56
              radius: 12
              color: ai.cItemHi

              // arquivo de texto: ícone + nome
              Row {
                visible: th.kind === "text"
                anchors.verticalCenter: parent.verticalCenter
                x: 10
                width: parent.width - 36
                spacing: 8

                Glyph {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "\uf15c" // file-text
                  color: ai.cAccent
                  font.pixelSize: 18
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 30

                  Label {
                    width: parent.width
                    text: th.name
                    font.pixelSize: 11
                  }

                  Label {
                    width: parent.width
                    text: th.trunc !== "" ? "truncado em 60 KB" : "texto"
                    color: ai.cMuted
                    font.pixelSize: 10
                  }
                }
              }

              Image {
                visible: th.kind === "image"
                anchors.fill: parent
                source: th.kind === "image" ? "file://" + th.path : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 112
                sourceSize.height: 112
              }

              Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 3
                width: 18
                height: 18
                radius: 9
                color: ai.cBg
                opacity: 0.9

                Glyph {
                  anchors.centerIn: parent
                  text: "\uf00d" // times
                  font.pixelSize: 9
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: ai.removeAttachment(th.index)
                }
              }
            }
          }

          // ainda processando uma imagem
          Rectangle {
            visible: attachProc.running
            width: 56
            height: 56
            radius: 12
            color: ai.cItem

            Label {
              anchors.centerIn: parent
              text: "…"
              color: ai.cMuted
            }
          }
        }

        // ---------- entrada ----------
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: inWrap.height + 20
          radius: 22
          color: ai.cItem
          opacity: (ai.model !== "" && ai.serverUp) ? 1 : 0.5

          RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 8

            // anexar imagem (arquivo) e colar imagem (área de transferência)
            RoundBtn {
              Layout.alignment: Qt.AlignBottom
              implicitWidth: 28
              implicitHeight: 28
              glyph: "\uf0c6" // paperclip: anexar arquivos
              onClicked: ai.pickFiles()
            }

            RoundBtn {
              Layout.alignment: Qt.AlignBottom
              implicitWidth: 28
              implicitHeight: 28
              opacity: ai.visionOk ? 1 : 0.4
              glyph: "\uf0ea" // paste
              onClicked: ai.attachClip(true)
            }

            Item {
              id: inWrap

              Layout.fillWidth: true
              height: Math.min(120, Math.max(22, input.contentHeight))

              Flickable {
                id: inFlick

                anchors.fill: parent
                contentWidth: width
                contentHeight: input.contentHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                function ensureVisible(r) {
                  if (contentY >= r.y) {
                    contentY = r.y;
                  } else if (contentY + height <= r.y + r.height) {
                    contentY = r.y + r.height - height;
                  }
                }

                TextEdit {
                  id: input

                  width: inFlick.width
                  wrapMode: TextEdit.Wrap
                  color: ai.cText
                  selectionColor: ai.cAccent
                  selectedTextColor: ai.cOnAccent
                  font.family: ai.nerdFont
                  font.pixelSize: 13
                  selectByMouse: true

                  onCursorRectangleChanged: inFlick.ensureVisible(input.cursorRectangle)

                  Keys.onPressed: (event) => {
                    // Ctrl+V: se houver imagem na área de transferência, anexa
                    // (o texto, se houver, continua sendo colado normalmente)
                    if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
                      ai.attachClip(false);
                    }

                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        && !(event.modifiers & Qt.ShiftModifier)) {
                      ai.submit();
                      event.accepted = true;
                    }
                  }
                }
              }

              Label {
                visible: input.text === ""
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                text: "Pergunte algo…"
                color: ai.cMuted
                font.pixelSize: 12
              }
            }

            RoundBtn {
              Layout.alignment: Qt.AlignBottom
              primary: true
              implicitWidth: 36
              implicitHeight: 36
              glyph: ai.busy ? "\uf04d" : "\uf1d8" // stop / paper-plane

              onClicked: {
                if (ai.busy) {
                  ai.stop();
                } else {
                  ai.submit();
                }
              }
            }
          }
        }
      }
    }
  }
}
