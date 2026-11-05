// logic/AiChat.qml — Chat com modelos do Ollama
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "ai".
// Acesso de fora:  phone.ai.<membro>

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // objetos usados por outros arquivos (acesso: phone.ai.<nome>)
  property alias aiAttachModel: aiAttachModelObj
  property alias aiAttachProc: aiAttachProcObj
  property alias aiChatModel: aiChatModelObj
  property alias aiTagsProc: aiTagsProcObj

  // item da view registrado por ela mesma (Binding em ui/OptionPopups.qml)
  property var aiOptViewRef: null

  // item da view registrado por ela mesma (Binding em views/AiView.qml)
  property var aiFlickRef: null

  // ================================================================
  // IA — conversa com modelos do Ollama (adaptado da AiSidebar)
  //
  // Fala com a API local (http://127.0.0.1:11434) via scripts/ai/ai-chat.sh
  // (curl em streaming, NDJSON). Anexos (imagem/texto/código) passam por
  // scripts/ai/ai-attach.sh. A conversa vive na memória do shell.
  // ================================================================

  property string aiBase: "http://127.0.0.1:11434"

  property int aiNumCtx: 8192               // 0 = padrão do modelo

  property string aiSystemPrompt: ""        // vazio = usa o SYSTEM do modelo

  readonly property string aiScriptDir:
    decodeURIComponent(String(Qt.resolvedUrl("../scripts/ai")).replace("file://", ""))

  property string aiModel: ""

  property var aiModels: []

  property bool aiServerUp: true

  property bool aiBusy: false

  property bool aiStopping: false

  property bool aiStick: true

  property bool aiAutoScroll: false

  property string aiNotice: ""

  property string aiPending: ""

  property bool aiVisionOk: true

  property bool aiCapsDirty: false

  property var aiAttachQueue: []

  property bool aiAttachExplicit: false

  property string aiInput: ""

  property bool aiOptOpen: false

  property bool aiPicker: false             // popup mostrando a lista de modelos

  property int aiOptSel: 0

  readonly property color aiSynKw: phone.pink

  readonly property color aiSynStr: phone.cOk

  readonly property color aiSynNum: phone.cNum

  readonly property string aiBanner:
    !aiServerUp
      ? "O Ollama não respondeu em " + aiBase + ". Ele está rodando?"
      : aiNotice

  readonly property string aiSubtitle:
    aiModel !== ""
      ? aiModel + (aiVisionOk ? " · visão" : "")
      : "sem modelo"

  readonly property var aiOpts: {
    if (aiPicker) {
      const out = [];

      for (let i = 0; i < aiModels.length; i++)
        out.push({ k: "m:" + i, t: (aiModels[i] === aiModel ? "• " : "   ") + aiModels[i] });

      if (out.length === 0)
        out.push({ k: "refresh", t: "Nenhum modelo (atualizar)" });

      return out;
    }

    const o = [
      { k: "model",  t: "Modelo: " + (aiModel !== "" ? aiModel : "—") },
      { k: "new",    t: "Nova conversa" },
      { k: "attach", t: "Anexar arquivo…" },
      { k: "clip",   t: "Colar imagem" }
    ];

    if (aiChatModel.count > 1) {
      o.push({ k: "regen", t: "Gerar de novo" });
      o.push({ k: "copy",  t: "Copiar resposta" });
    }

    if (aiAttachModel.count > 0)
      o.push({ k: "unattach", t: "Remover anexos" });

    o.push({ k: "refresh", t: "Atualizar modelos" });

    return o;
  }

  ListModel {
    id: aiChatModelObj
  }

  ListModel {
    id: aiAttachModelObj
  }

  onAiModelChanged: aiRefreshCaps()

  onAiOptOpenChanged: {
    if (aiOptOpen)
      aiOptSel = 0;
    else
      aiPicker = false;
  }

  // ---------------- ciclo de vida ----------------

  function aiEnter() {
    aiOptOpen = false;

    if (!aiTagsProc.running)
      aiTagsProc.running = true;

    Qt.callLater(aiScrollEnd);
  }

  function aiScrollEnd() {
    if (!aiFlickRef)
      return;

    aiAutoScroll = true;
    aiFlickRef.contentY = Math.max(0, aiFlickRef.contentHeight - aiFlickRef.height);
    aiAutoScroll = false;
    aiStick = true;
  }

  function aiScrollBy(d) {
    if (!aiFlickRef)
      return;

    const max = Math.max(0, aiFlickRef.contentHeight - aiFlickRef.height);

    aiAutoScroll = true;
    aiFlickRef.contentY = Math.max(0, Math.min(max, aiFlickRef.contentY + d));
    aiAutoScroll = false;
    aiStick = aiFlickRef.contentY >= max - 8;
  }

  // ---------------- pedido ----------------

  // histórico enviado ao modelo: sem o balão vazio da resposta que vai chegar,
  // limitado em mensagens e em caracteres (o JSON vai como argumento do curl)
  function aiBuildHistory() {
    const LIMIT = 24000;
    const msgs = [];
    const n = aiChatModel.count - 1;

    for (let i = 0; i < n; i++) {
      const m = aiChatModel.get(i);
      const c = m.content.length > LIMIT ? m.content.slice(0, LIMIT) : m.content;

      // arquivos de texto: o conteúdo entra depois do texto, num bloco com cerca
      // de 4 crases; ai-chat.sh troca o marcador pelo conteúdo
      let withFiles = c;

      if (m.files && m.files !== "") {
        for (const f of JSON.parse(m.files)) {
          withFiles += "\n\n[Arquivo: " + f.name + (f.trunc ? " (truncado)" : "")
            + "]\n````\n@@TXT:" + f.path + "@@\n````";
        }
      }

      const msg = { role: m.role, content: withFiles };

      if (m.images && m.images !== "")
        msg.images = JSON.parse(m.images).map(p => "@@IMG:" + p + "@@");

      msgs.push(msg);
    }

    let total = 0;
    let start = msgs.length;

    for (let i = msgs.length - 1; i >= 0 && msgs.length - i <= 40; i--) {
      total += msgs[i].content.length;

      if (total > LIMIT && start < msgs.length)
        break;

      start = i;
    }

    const out = [];

    if (aiSystemPrompt !== "")
      out.push({ role: "system", content: aiSystemPrompt });

    return out.concat(msgs.slice(start));
  }

  function aiSubmit() {
    const typed = aiInput.trim();
    const imgs = [];
    const files = [];

    for (let i = 0; i < aiAttachModel.count; i++) {
      const at = aiAttachModel.get(i);

      if (at.kind === "image")
        imgs.push(at.path);
      else
        files.push({ path: at.path, name: at.name, trunc: at.trunc !== "" });
    }

    if ((typed === "" && imgs.length === 0 && files.length === 0) || aiBusy || aiModel === "" || !aiServerUp)
      return;

    if (aiAttachProc.running || aiAttachQueue.length > 0) {
      aiNotice = "Espera o anexo terminar de ser processado.";
      return;
    }

    if (imgs.length > 0 && !aiVisionOk) {
      aiNotice = "O modelo " + aiModel + " não aceita imagens. Escolha um com visão.";
      return;
    }

    let t = typed;

    if (t === "") {
      if (imgs.length === 0)
        t = files.length > 1 ? "Analise estes arquivos." : "Analise este arquivo.";
      else
        t = imgs.length > 1 ? "Descreva estas imagens." : "Descreva esta imagem.";
    }

    aiNotice = "";
    aiOptOpen = false;

    aiChatModel.append({
      role: "user",
      content: t,
      stats: "",
      images: imgs.length > 0 ? JSON.stringify(imgs) : "",
      files: files.length > 0 ? JSON.stringify(files) : ""
    });
    aiChatModel.append({ role: "assistant", content: "", stats: "", images: "", files: "" });

    aiAttachModel.clear();
    aiInput = "";

    aiStartRequest();
  }

  // dispara o pedido com o histórico atual; o último item do modelo é sempre
  // o balão vazio da resposta que vai chegar (também usado pra gerar de novo)
  function aiStartRequest() {
    const body = {
      model: aiModel,
      messages: aiBuildHistory(),
      stream: true
    };

    if (aiNumCtx > 0)
      body.options = { num_ctx: aiNumCtx };

    aiPending = "";
    aiStopping = false;
    aiBusy = true;

    aiChatProc.command = ["bash", aiScriptDir + "/ai-chat.sh", JSON.stringify(body), aiBase];
    aiChatProc.running = true;

    aiScrollEnd();
  }

  function aiStop() {
    if (aiBusy) {
      aiStopping = true;
      aiChatProc.running = false;
    }
  }

  function aiNewChat() {
    aiStop();
    aiFlushTimer.stop();
    aiPending = "";
    aiNotice = "";

    // apaga as imagens/textos temporários da conversa e dos anexos pendentes
    const paths = [];

    for (let i = 0; i < aiChatModel.count; i++) {
      const im = aiChatModel.get(i).images;

      if (im && im !== "")
        JSON.parse(im).forEach(p => paths.push(p));

      const fs = aiChatModel.get(i).files;

      if (fs && fs !== "")
        JSON.parse(fs).forEach(f => paths.push(f.path));
    }

    for (let i = 0; i < aiAttachModel.count; i++)
      paths.push(aiAttachModel.get(i).path);

    aiAttachModel.clear();
    aiChatModel.clear();

    if (paths.length > 0)
      Quickshell.execDetached(["rm", "-f"].concat(paths));
  }

  // joga os tokens acumulados no último balão
  function aiFlush() {
    if (aiChatModel.count === 0 || aiPending === "")
      return;

    const i = aiChatModel.count - 1;

    aiChatModel.setProperty(i, "content", aiChatModel.get(i).content + aiPending);
    aiPending = "";
  }

  // uma linha do NDJSON do /api/chat
  function aiOnChatLine(line) {
    if (line.trim() === "")
      return;

    let o;

    try {
      o = JSON.parse(line);
    } catch (e) {
      return;
    }

    if (o.error) {
      aiNotice = String(o.error);
      return;
    }

    if (o.message && o.message.content) {
      aiPending += o.message.content;

      if (!aiFlushTimer.running)
        aiFlushTimer.start();
    }

    if (o.done) {
      aiFlush();

      if (o.eval_count && o.eval_duration && aiChatModel.count > 0) {
        const tps = o.eval_count / (o.eval_duration / 1e9);

        aiChatModel.setProperty(aiChatModel.count - 1, "stats",
          o.eval_count + " tokens · " + tps.toFixed(1) + " tok/s");
      }
    }
  }

  function aiOnChatExit(code) {
    aiFlushTimer.stop();
    aiFlush();
    aiBusy = false;

    const last = aiChatModel.count - 1;
    const empty = last >= 0
      && aiChatModel.get(last).role === "assistant"
      && aiChatModel.get(last).content === "";

    if (!aiStopping && code !== 0 && aiNotice === "") {
      if (code === 7)
        aiServerUp = false;
      else
        aiNotice = "O curl terminou com erro (código " + code + ").";
    } else if (!aiStopping && empty && aiNotice === "") {
      aiNotice = "O modelo não devolveu nenhuma resposta.";
    }

    const ok = !aiStopping && code === 0 && aiNotice === "" && !empty;

    // balão vazio (parou antes do primeiro token, ou deu erro): remove
    if (empty)
      aiChatModel.remove(last);

    aiStopping = false;

    if (ok)
      aiNotifyDone();
  }

  // avisa que a resposta terminou, se você não está olhando o chat
  function aiNotifyDone() {
    if (phone.panelOpen && phone.view === "ai")
      return;

    const last = aiChatModel.count - 1;

    if (last < 0 || aiChatModel.get(last).role !== "assistant")
      return;

    let txt = aiChatModel.get(last).content
      .replace(/(`{3,}|~{3,})[\s\S]*?(\1|$)/g, " (código) ")
      .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
      .replace(/[#*_`>~\[\]]/g, "")
      .replace(/\s+/g, " ")
      .trim();

    if (txt.length > 140)
      txt = txt.slice(0, 137) + "…";

    Quickshell.execDetached([
      "notify-send", "-a", "Ollama", "-t", "8000",
      aiModel + " respondeu",
      txt !== "" ? txt : "A resposta está pronta."
    ]);
  }

  // gera a última resposta de novo (descarta a atual e refaz o pedido)
  function aiRegenerate() {
    const last = aiChatModel.count - 1;

    if (aiBusy || last < 1 || aiChatModel.get(last).role !== "assistant")
      return;

    aiNotice = "";
    aiChatModel.setProperty(last, "content", "");
    aiChatModel.setProperty(last, "stats", "");
    aiStartRequest();
  }

  function aiCopyLast() {
    for (let i = aiChatModel.count - 1; i >= 0; i--) {
      const m = aiChatModel.get(i);

      if (m.role === "assistant" && m.content !== "") {
        Quickshell.execDetached(["wl-copy", "--", m.content]);
        aiNotice = "";
        return;
      }
    }
  }

  // ---------------- modelos ----------------

  function aiParseTags(text) {
    try {
      const j = JSON.parse(text);
      const names = (j.models || []).map(m => m.name);

      aiModels = names;
      aiServerUp = true;

      if (names.length === 0)
        aiModel = "";
      else if (names.indexOf(aiModel) < 0)
        aiModel = names[0];
    } catch (e) {
      aiServerUp = false;
    }
  }

  // pergunta ao Ollama se o modelo atual tem a capacidade "vision"
  function aiRefreshCaps() {
    if (aiModel === "") {
      aiVisionOk = false;
      return;
    }

    if (aiShowProc.running) {
      aiCapsDirty = true;
      return;
    }

    aiCapsDirty = false;

    aiShowProc.command = [
      "curl", "-s", "--max-time", "5", "-X", "POST",
      aiBase + "/api/show",
      "-d", JSON.stringify({ model: aiModel })
    ];

    aiShowProc.running = true;
  }

  function aiParseShow(text) {
    try {
      const j = JSON.parse(text);

      // Ollama antigo não manda "capabilities": deixa tentar
      aiVisionOk = Array.isArray(j.capabilities)
        ? j.capabilities.indexOf("vision") >= 0
        : true;
    } catch (e) {
      aiVisionOk = true;
    }

    if (aiCapsDirty)
      aiRefreshCaps();
  }

  // ---------------- anexos ----------------

  // src = caminho de arquivo, ou "-clip" pra imagem da área de transferência
  function aiAttach(src, explicit) {
    if (src === "")
      return;

    const inFlight = aiAttachModel.count + aiAttachQueue.length + (aiAttachProc.running ? 1 : 0);

    if (inFlight >= 6) {
      if (explicit)
        aiNotice = "Máximo de 6 anexos por mensagem.";

      return;
    }

    aiAttachQueue = aiAttachQueue.concat([{ src: src, explicit: explicit }]);
    aiNextAttach();
  }

  function aiNextAttach() {
    if (aiAttachProc.running || aiAttachQueue.length === 0)
      return;

    const job = aiAttachQueue[0];

    aiAttachQueue = aiAttachQueue.slice(1);
    aiAttachExplicit = job.explicit;
    aiAttachProc.command = ["bash", aiScriptDir + "/ai-attach.sh", job.src];
    aiAttachProc.running = true;
  }

  // uma linha do ai-attach.sh: "image<TAB>caminho" ou "text<TAB>caminho<TAB>nome<TAB>trunc"
  function aiAddAttachment(line) {
    const f = line.replace(/\r?\n$/, "").split("\t");

    if (f.length < 2 || f[1] === "")
      return;

    if (f[0] === "image") {
      if (!aiVisionOk) {
        // imagem num modelo sem visão: descarta (só avisa se foi de propósito)
        Quickshell.execDetached(["rm", "-f", f[1]]);

        if (aiAttachExplicit)
          aiNotice = "O modelo " + aiModel + " não aceita imagens. Escolha um com visão.";

        return;
      }

      aiAttachModel.append({ kind: "image", path: f[1], name: "", trunc: "" });
    } else if (f[0] === "text") {
      aiAttachModel.append({ kind: "text", path: f[1], name: f[2] || "arquivo", trunc: f[3] || "" });
    }
  }

  function aiOnAttachExit(code) {
    if (code === 3 && aiAttachExplicit)
      aiNotice = "Não há imagem na área de transferência (o wl-paste está instalado?).";
    else if (code === 4)
      aiNotice = "Não consegui ler esse arquivo.";
    else if (code === 5)
      aiNotice = "Não consegui converter a imagem. Isso é mesmo uma imagem?";
    else if (code === 6)
      aiNotice = "Esse tipo de arquivo não dá pra anexar (só imagem, texto e código).";
    else if (code !== 0 && code !== 3)
      aiNotice = "Falha ao anexar (código " + code + ").";

    Qt.callLater(aiNextAttach);
  }

  function aiRemoveAttachment(i) {
    const p = aiAttachModel.get(i).path;

    aiAttachModel.remove(i);
    Quickshell.execDetached(["rm", "-f", p]);
  }

  function aiClearAttachments() {
    const paths = [];

    for (let i = 0; i < aiAttachModel.count; i++)
      paths.push(aiAttachModel.get(i).path);

    aiAttachModel.clear();

    if (paths.length > 0)
      Quickshell.execDetached(["rm", "-f"].concat(paths));
  }

  // escolhe o arquivo no próprio "Meus arquivos" do celular
  function aiPickFile() {
    phone.files.filesPick = true;
    phone.files.filesPickUpload = false;
    phone.files.filesPickAi = true;
    phone.files.filesReturnView = "ai";
    phone.files.filesDir = phone.files.homeDir;
    phone.view = "files";
  }

  // Ctrl+V: cola texto e, se houver imagem na área de transferência, anexa
  function aiPaste() {
    if (!aiPasteProc.running)
      aiPasteProc.running = true;

    aiAttach("-clip", false);
  }

  // ---------------- código: blocos e realce de sintaxe ----------------

  // divide uma resposta em trechos {type: "text"|"code", text, lang}. Uma cerca
  // ``` ainda sem fechar (streaming) vira um bloco de código aberto.
  function aiParseSegments(content) {
    const segs = [];
    let buf = [];
    let inCode = false;
    let lang = "";

    function pushText() {
      const t = buf.join("\n").replace(/^(\s*\n)+/, "").replace(/\s+$/, "");

      if (t !== "")
        segs.push({ type: "text", text: t, lang: "" });

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

    if (inCode)
      segs.push({ type: "code", text: buf.join("\n"), lang: lang });
    else
      pushText();

    return segs;
  }

  // mensagens do usuário não são Markdown: viram um trecho de texto puro
  function aiUserSegs(content) {
    return content === "" ? [] : [{ type: "plain", text: content, lang: "" }];
  }

  function aiEsc(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  // código -> HTML (RichText). Reconhece comentários, strings, números e
  // palavras-chave de algumas famílias; o resto fica sem cor. O texto do
  // código nunca é alterado: só ganha <span> em volta (& < > escapados).
  function aiHighlight(code, lang) {
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

    if (fam === "")
      return open + aiEsc(code) + "</p>";

    const cKw = String(aiSynKw);
    const cStr = String(aiSynStr);
    const cNum = String(aiSynNum);
    const cCom = String(phone.txtMuted);

    const kw = {};

    KW[fam].split(" ").forEach(w => {
      if (w !== "")
        kw[w] = 1;
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

        if (Object.prototype.hasOwnProperty.call(kw, key))
          col = cKw;
        else if (Object.prototype.hasOwnProperty.call(LIT, t))
          col = cNum;
      }

      out += aiEsc(code.slice(last, m.index));
      out += col === ""
        ? aiEsc(t)
        : '<span style="color:' + col + (italic ? ";font-style:italic" : "") + '">' + aiEsc(t) + "</span>";
      last = m.index + t.length;
    }

    return open + out + aiEsc(code.slice(last)) + "</p>";
  }

  // ---------------- popup de opções ----------------

  function aiOptRun(k) {
    // "Modelo:" só troca a lista; o popup continua aberto
    if (k === "model") {
      aiPicker = true;

      const i = aiModels.indexOf(aiModel);

      aiOptSel = Math.max(0, i);
      return;
    }

    aiOptOpen = false;

    if (k.indexOf("m:") === 0) {
      const mi = parseInt(k.slice(2));

      if (mi >= 0 && mi < aiModels.length)
        aiModel = aiModels[mi];

      return;
    }

    switch (k) {
    case "new":      aiNewChat(); break;
    case "attach":   aiPickFile(); break;
    case "clip":     aiAttach("-clip", true); break;
    case "regen":    aiRegenerate(); break;
    case "copy":     aiCopyLast(); break;
    case "unattach": aiClearAttachments(); break;

    case "refresh":
      if (!aiTagsProc.running)
        aiTagsProc.running = true;
      break;
    }
  }

  function handleAiOptKey(e) {
    const n = aiOpts.length;

    switch (e.key) {
    case Qt.Key_Up:    aiOptSel = (aiOptSel + n - 1) % n; break;
    case Qt.Key_Down:  aiOptSel = (aiOptSel + 1) % n;     break;

    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Right:
      aiOptRun(aiOpts[Math.min(aiOptSel, n - 1)].k);
      break;

    case Qt.Key_Escape:
    case Qt.Key_Left:
      aiBack();
      break;

    default:
      return;
    }

    e.accepted = true;
  }

  // ---------------- teclado e softkeys ----------------

  function handleAiKey(e) {
    if (aiOptOpen) {
      handleAiOptKey(e);
      return;
    }

    const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
    let ok = true;

    if (ctrl && e.key === Qt.Key_V)
      aiPaste();
    else if (ctrl && e.key === Qt.Key_C)
      aiStop();
    else if (ctrl && e.key === Qt.Key_N)
      aiNewChat();
    else
      ok = aiKey(e);

    if (ok)
      e.accepted = true;
  }

  function aiKey(e) {
    switch (e.key) {
    case Qt.Key_Escape:
      phone.view = "menu";
      return true;

    case Qt.Key_Tab:
      aiPicker = true;
      aiOptOpen = true;
      aiOptSel = Math.max(0, aiModels.indexOf(aiModel));
      return true;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      if (e.modifiers & Qt.ShiftModifier)
        aiInput += "\n";
      else
        aiSubmit();

      return true;

    case Qt.Key_Backspace:
      aiInput = aiInput.slice(0, -1);
      return true;

    case Qt.Key_Up:       aiScrollBy(-phone.s(40)); return true;
    case Qt.Key_Down:     aiScrollBy(phone.s(40));  return true;
    case Qt.Key_PageUp:   aiScrollBy(-aiFlickRef.height * 0.8); return true;
    case Qt.Key_PageDown: aiScrollBy(aiFlickRef.height * 0.8);  return true;

    default:
      if (e.text && e.text.length === 1 && e.text >= " ") {
        aiInput += e.text;
        return true;
      }

      return false;
    }
  }

  function aiLeftKey() {
    aiPicker = false;
    aiOptOpen = !aiOptOpen;
  }

  function aiCenterKey() {
    if (aiOptOpen) {
      aiOptRun(aiOpts[Math.min(aiOptSel, aiOpts.length - 1)].k);
      return;
    }

    if (aiBusy)
      aiStop();
    else
      aiSubmit();
  }

  function aiBack() {
    if (aiOptOpen) {
      if (aiPicker) {
        aiPicker = false;
        aiOptSel = 0;
      } else {
        aiOptOpen = false;
      }

      return;
    }

    // sai do app; uma resposta em andamento continua e avisa quando terminar
    phone.view = "menu";
  }

  // ---------------- processos ----------------

  Process {
    id: aiTagsProcObj

    command: ["curl", "-s", "--max-time", "3", phone.ai.aiBase + "/api/tags"]

    stdout: StdioCollector {
      onStreamFinished: phone.ai.aiParseTags(this.text)
    }
  }

  Process {
    id: aiChatProc

    stdout: SplitParser {
      onRead: (data) => phone.ai.aiOnChatLine(data)
    }

    onExited: (code, status) => phone.ai.aiOnChatExit(code)
  }

  Process {
    id: aiShowProc

    stdout: StdioCollector {
      onStreamFinished: phone.ai.aiParseShow(this.text)
    }
  }

  Process {
    id: aiAttachProcObj

    stdout: SplitParser {
      onRead: (data) => phone.ai.aiAddAttachment(data)
    }

    onExited: (code, status) => phone.ai.aiOnAttachExit(code)
  }

  // Ctrl+V: só texto (uma imagem na área de transferência não vira lixo no campo)
  Process {
    id: aiPasteProc

    command: ["wl-paste", "-n", "-t", "text"]

    stdout: StdioCollector {
      onStreamFinished: {
        const t = this.text.replace(/[\x00-\x08\x0b\x0c\x0e-\x1f]/g, "");

        if (t !== "")
          phone.ai.aiInput += t;
      }
    }
  }

  // junta tokens em lotes: reprocessar Markdown a cada token pesa à toa
  Timer {
    id: aiFlushTimer

    interval: 60
    repeat: true

    onTriggered: phone.ai.aiFlush()
  }

  // mantém o item selecionado do popup visível (lista com rolagem)
  onAiOptSelChanged: {
    if (aiOptOpen)
      aiOptViewRef?.positionViewAtIndex(aiOptSel, ListView.Contain);
  }
}
