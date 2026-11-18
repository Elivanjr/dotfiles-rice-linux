
 // apps/news/NewsApp.qml — Notícias por tópico (RSS): tecnologia, jogos, animes, política
 //
 // Módulo de lógica, sem visual.
 // Instanciado em shell.qml como "news".
 //
 // Acesso externo: phone.news.<membro>
 // Tela: NewsView.qml
 // Helper: helper/news-helper.py

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // ---------------- estado ----------------

  property string newsStage: "list" // list | detail
  property int newsTab: 0           // índice em newsTopics

  property var newsItems: []
  property int newsSel: 0

  property bool newsLoading: false
  property string newsError: ""
  property string newsNote: ""

  property var newsFailed: []

  property int newsUpdatedAt: 0
  property bool newsFromCache: false
  property bool newsGot: false

  // busca digitada na lista (vazio = sem busca) e busca na web em andamento
  property string newsQuery: ""
  property bool newsWebBusy: false

  readonly property var newsTabs: ["Tecnologia", "Jogos", "Animes", "Política", "Linux"]

  // ids dos tópicos, na mesma ordem de newsTabs (vêm do campo "topico" do feed)
  readonly property var newsTopics: ["tecnologia", "jogos", "animes", "politica", "linux"]

  // ---------------- caminhos ----------------

  readonly property string newsScript:
    decodeURIComponent(
      String(Qt.resolvedUrl("helper/news-helper.py"))
        .replace("file://", "")
    )

  // ---------------- dados derivados ----------------

  // itens sem tópico (cache antigo) caem em Política
  // com busca: todas as notícias salvas (de qualquer tópico); sem busca: a aba
  readonly property var newsList:
    newsQuery !== ""
      ? newsItems.filter(it => newsMatches(it, newsQuery))
      : newsItems.filter(
          it => (it.topico || "politica") === newsTopics[newsTab]
        )

  readonly property var newsCurrent:
    newsSel >= 0 && newsSel < newsList.length
      ? newsList[newsSel]
      : null

  function newsCount(tab) {
    const topico = newsTopics[tab];

    return newsItems.filter(
      it => (it.topico || "politica") === topico
    ).length;
  }

  // ---------------- textos ----------------

  function pad2(n) {
    return (n < 10 ? "0" : "") + n;
  }

  function ageText(epoch) {
    if (!epoch)
      return "";

    const now = phone.music.now.getTime();
    const secs = Math.max(
      0,
      Math.round((now - epoch * 1000) / 1000)
    );

    if (secs < 60)
      return "agora";

    if (secs < 3600)
      return "há " + Math.floor(secs / 60) + " min";

    if (secs < 86400)
      return "há " + Math.floor(secs / 3600) + " h";

    if (secs < 172800)
      return "ontem";

    if (secs < 7 * 86400)
      return "há " + Math.floor(secs / 86400) + " dias";

    const d = new Date(epoch * 1000);

    return pad2(d.getDate()) + "/" + pad2(d.getMonth() + 1);
  }

  readonly property string newsTitle:
    newsStage === "detail" ? "Notícia" : "Notícias"

  readonly property string newsSubtitle: {
    if (newsStage === "detail") {
      return newsCurrent
        ? newsCurrent.fonte
          + (newsCurrent.data
            ? " · " + ageText(newsCurrent.data)
            : "")
        : "";
    }

    if (newsLoading)
      return "Buscando…";

    if (newsError !== "")
      return "Sem notícias";

    if (newsUpdatedAt === 0)
      return "";

    return (newsFromCache ? "Salvo " : "Atualizado ")
      + ageText(newsUpdatedAt);
  }

  readonly property string newsFooter: {
    if (newsNote !== "")
      return newsNote;

    if (newsFailed.length > 0) {
      return newsFailed.length
        + (newsFailed.length === 1
          ? " fonte falhou: "
          : " fontes falharam: ")
        + newsFailed.map(
          f => f.fonte + " (" + f.erro + ")"
        ).join(", ");
    }

    return newsLoading
      ? "Buscando notícias…"
      : "←→ aba · digite para buscar · F5 atualiza";
  }

  readonly property string newsSoftLeft:
    newsStage === "detail" ? "Copiar"
      : (newsQuery !== "" ? "Limpar" : "Atualizar")

  readonly property string newsSoftCenter:
    newsStage === "detail"
      ? "Abrir"
      : (newsCurrent ? "Ler" : (newsQuery !== "" ? "Buscar web" : ""))

  readonly property string newsSoftRight: "Voltar"

  readonly property string softLeftText: newsSoftLeft

  readonly property string softCenterText: newsSoftCenter

  readonly property string softRightText: newsSoftRight

  // ---------------- coleta ----------------

  // minúsculas e sem acento, para comparar
  function newsFold(texto) {
    return String(texto).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  }

  // todas as palavras digitadas precisam aparecer no título, resumo ou fonte
  function newsMatches(item, query) {
    const texto = newsFold(item.titulo + " " + item.resumo + " " + item.fonte);

    return newsFold(query).split(" ")
      .filter(p => p !== "")
      .every(p => texto.indexOf(p) >= 0);
  }

  function newsSetQuery(texto) {
    newsQuery = texto;
    newsSel = 0;
    newsNote = "";
  }

  function newsEnter() {
    newsStage = "list";
    newsNote = "";
    newsRefresh(false);
  }

  function newsRefresh(force) {
    if (newsProc.running)
      return;

    newsLoading = true;
    newsGot = false;

    newsError = "";
    newsNote = "";

    newsSettleTimer.stop();

    newsProc.command = [
      "python3",
      newsScript,
      "fetch",
      "--max-age",
      "900"
    ].concat(force ? ["--force"] : []);

    newsProc.running = true;
  }

  // resultado da busca na web: junta as notícias novas às já salvas
  function newsOnSearch(text) {
    newsWebBusy = false;
    newsLoading = false;

    for (const raw of text.split("\n")) {
      const line = raw.trim();

      if (line.indexOf("ERROR ") === 0) {
        newsNote = line.slice(6);
        return;
      }

      if (line.indexOf("NEWS ") !== 0)
        continue;

      let data = null;

      try {
        data = JSON.parse(line.slice(5));
      } catch (e) {
        newsNote = "Resposta inesperada da busca.";
        return;
      }

      const links = new Set(newsItems.map(it => it.link));
      const novos = (data.itens || []).filter(it => !links.has(it.link));

      newsItems = newsItems.concat(novos);
      newsSel = 0;
      newsNote = novos.length > 0
        ? novos.length + " da web para \"" + newsQuery + "\""
        : "Nada na web para \"" + newsQuery + "\".";
      return;
    }

    newsNote = "Busca sem resposta.";
  }

  function newsWebSearch(termo) {
    if (newsWebBusy || newsSearchProc.running)
      return;

    newsWebBusy = true;
    newsLoading = true;
    newsNote = "Buscando na web…";

    newsSearchProc.command = ["python3", newsScript, "search", "--termo", termo];
    newsSearchProc.running = true;
  }

  function newsOnResult(text) {
    const lines = text.split("\n");

    for (const raw of lines) {
      const line = raw.trim();

      if (line.indexOf("ERROR ") === 0) {
        newsGot = true;
        newsLoading = false;

        newsError = line.slice(6);

        if (newsItems.length === 0)
          newsFailed = [];

        return;
      }

      if (line.indexOf("NEWS ") !== 0)
        continue;

      let data = null;

      try {
        data = JSON.parse(line.slice(5));
      } catch (e) {
        newsGot = true;
        newsLoading = false;

        newsError = "Resposta inesperada do script de notícias.";
        return;
      }

      newsGot = true;
      newsLoading = false;
      newsError = "";

      newsApply(data);
      return;
    }
  }

  function newsApply(data) {
    // Preserva a notícia selecionada, se ela ainda existir.
    const keep = newsCurrent ? newsCurrent.link : "";

    newsItems = data.itens || [];
    newsFailed = data.erros || [];

    newsUpdatedAt = data.geradoEm || 0;
    newsFromCache = data.doCache === true;

    newsNote = data.aviso || "";

    let idx = -1;

    for (let i = 0; i < newsList.length; i++) {
      if (newsList[i].link === keep) {
        idx = i;
        break;
      }
    }

    if (idx < 0 && newsList.length > 0)
      idx = 0;

    newsSel = idx;

    if (newsStage === "detail" && newsCurrent === null)
      newsStage = "list";
  }

  // ---------------- encerramento ----------------

  function newsOnExit() {
    if (!newsGot)
      newsSettleTimer.restart();
  }

  function newsSettle() {
    if (newsGot)
      return;

    newsLoading = false;

    newsError =
      "O script terminou sem resposta. O python3 está instalado?";
  }

  // ---------------- navegação ----------------

  // ←→ passa de tópico em tópico (dá a volta no fim)
  function newsCycle(delta) {
    const total = newsTabs.length;

    newsSetTab((newsTab + delta + total) % total);
  }

  function newsSetTab(tab) {
    if (tab < 0 || tab >= newsTabs.length || tab === newsTab)
      return;

    newsTab = tab;

    newsSel = newsList.length > 0 ? 0 : -1;
    newsNote = "";
  }

  function newsMove(delta) {
    const count = newsList.length;

    if (count === 0)
      return;

    newsSel = Math.max(
      0,
      Math.min(count - 1, newsSel + delta)
    );

    newsNote = "";
  }

  function newsRead() {
    if (newsCurrent)
      newsStage = "detail";
  }

  function newsBackToList() {
    newsStage = "list";
    newsNote = "";
  }

  // ---------------- ações ----------------

  function newsOpen() {
    const item = newsCurrent;

    if (!item)
      return;

    if (!/^https?:\/\//i.test(item.link)) {
      newsNote = "Link inválido.";
      return;
    }

    Quickshell.execDetached([
      "xdg-open",
      item.link
    ]);

    newsNote = "Abrindo no navegador…";
  }

  function newsCopy() {
    const item = newsCurrent;

    if (!item)
      return;

    Quickshell.execDetached([
      "wl-copy",
      "--",
      item.link
    ]);

    newsNote = "Link copiado.";
  }

  // ---------------- teclado ----------------

  function handleNewsKey(event) {
    const handled = newsStage === "detail"
      ? newsDetailKey(event)
      : newsListKey(event);

    if (handled)
      event.accepted = true;
  }

  function handleKey(event) {
    handleNewsKey(event);
  }

  function newsListKey(event) {
    switch (event.key) {
    case Qt.Key_Escape:
      if (newsQuery !== "") {
        newsSetQuery("");
        return true;
      }
      phone.view = "menu";
      return true;

    case Qt.Key_Backspace:
      if (newsQuery === "")
        return false;
      newsSetQuery(newsQuery.slice(0, -1));
      return true;

    case Qt.Key_Left:
      newsCycle(-1);
      return true;

    case Qt.Key_Right:
      newsCycle(1);
      return true;

    case Qt.Key_Tab:
      newsSetTab((newsTab + 1) % newsTabs.length);
      return true;

    case Qt.Key_Up:
      newsMove(-1);
      return true;

    case Qt.Key_Down:
      newsMove(1);
      return true;

    case Qt.Key_PageUp:
      newsMove(-4);
      return true;

    case Qt.Key_PageDown:
      newsMove(4);
      return true;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      if (newsQuery !== "" && newsList.length === 0)
        newsWebSearch(newsQuery);
      else
        newsRead();
      return true;

    case Qt.Key_F5:
      newsRefresh(true);
      return true;

    default:
      // qualquer letra ou número vira busca (Ctrl+tecla fica de fora)
      if (event.text && event.text.length === 1 && event.text >= " "
          && (event.modifiers & Qt.ControlModifier) === 0) {
        newsSetQuery(newsQuery + event.text);
        return true;
      }
      return false;
    }
  }

  function newsDetailKey(event) {
    switch (event.key) {
    case Qt.Key_Escape:
    case Qt.Key_Left:
    case Qt.Key_Backspace:
      newsBackToList();
      return true;

    case Qt.Key_Up:
      newsMove(-1);
      return true;

    case Qt.Key_Down:
      newsMove(1);
      return true;

    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_O:
      newsOpen();
      return true;

    case Qt.Key_C:
      newsCopy();
      return true;

    default:
      return false;
    }
  }

  // ---------------- softkeys ----------------

  function newsLeftKey() {
    if (newsStage === "detail")
      newsCopy();
    else if (newsQuery !== "")
      newsSetQuery("");
    else
      newsRefresh(true);
  }

  function newsCenterKey() {
    if (newsStage === "detail")
      newsOpen();
    else if (!newsCurrent && newsQuery !== "")
      newsWebSearch(newsQuery);
    else
      newsRead();
  }

  function newsBack() {
    if (newsStage === "detail")
      newsBackToList();
    else
      phone.view = "menu";
  }

  function softLeft() {
    newsLeftKey();
  }

  function softCenter() {
    newsCenterKey();
  }

  function softRight() {
    newsBack();
  }

  // ---------------- processos ----------------

  Timer {
    interval: 900000
    repeat: true

    running: phone.panelOpen && phone.view === "news"

    onTriggered: phone.news.newsRefresh(false)
  }

  Timer {
    id: newsSettleTimer

    interval: 400

    onTriggered: phone.news.newsSettle()
  }

  Process {
    id: newsSearchProc

    stdout: StdioCollector {
      onStreamFinished: phone.news.newsOnSearch(this.text)
    }
  }

  Process {
    id: newsProc

    stdout: StdioCollector {
      onStreamFinished: phone.news.newsOnResult(this.text)
    }

    onExited: (code, status) => phone.news.newsOnExit()
  }
}

