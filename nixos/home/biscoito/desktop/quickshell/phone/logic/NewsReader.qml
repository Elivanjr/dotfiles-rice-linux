
 // logic/NewsReader.qml — Notícias do Brasil e do Mundo (RSS)
 //
 // Módulo de lógica, sem visual.
 // Instanciado em shell.qml como "news".
 //
 // Acesso externo: phone.news.<membro>
 // Tela: views/NewsView.qml
 // Script: scripts/news/news-helper.py

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // ---------------- estado ----------------

  property string newsStage: "list" // list | detail
  property int newsTab: 0           // 0 = Brasil, 1 = Mundo

  property var newsItems: []
  property int newsSel: 0

  property bool newsLoading: false
  property string newsError: ""
  property string newsNote: ""

  property var newsFailed: []

  property int newsUpdatedAt: 0
  property bool newsFromCache: false
  property bool newsGot: false

  readonly property var newsTabs: ["Brasil", "Mundo"]

  // ---------------- caminhos ----------------

  readonly property string newsScript:
    decodeURIComponent(
      String(Qt.resolvedUrl("../scripts/news/news-helper.py"))
        .replace("file://", "")
    )

  // ---------------- dados derivados ----------------

  readonly property var newsList:
    newsItems.filter(
      it => it.grupo === (newsTab === 0 ? "brasil" : "mundo")
    )

  readonly property var newsCurrent:
    newsSel >= 0 && newsSel < newsList.length
      ? newsList[newsSel]
      : null

  function newsCount(tab) {
    const grupo = tab === 0 ? "brasil" : "mundo";

    return newsItems.filter(it => it.grupo === grupo).length;
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
      : "←→ aba · Enter lê · R atualiza";
  }

  readonly property string newsSoftLeft:
    newsStage === "detail" ? "Copiar" : "Atualizar"

  readonly property string newsSoftCenter:
    newsStage === "detail"
      ? "Abrir"
      : (newsCurrent ? "Ler" : "")

  readonly property string newsSoftRight: "Voltar"

  // ---------------- coleta ----------------

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

  function newsListKey(event) {
    switch (event.key) {
    case Qt.Key_Escape:
      phone.view = "menu";
      return true;

    case Qt.Key_Left:
      newsSetTab(newsTab - 1);
      return true;

    case Qt.Key_Right:
      newsSetTab(newsTab + 1);
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
      newsRead();
      return true;

    case Qt.Key_R:
    case Qt.Key_F5:
      newsRefresh(true);
      return true;

    default:
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
    else
      newsRefresh(true);
  }

  function newsCenterKey() {
    if (newsStage === "detail")
      newsOpen();
    else
      newsRead();
  }

  function newsBack() {
    if (newsStage === "detail")
      newsBackToList();
    else
      phone.view = "menu";
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
    id: newsProc

    stdout: StdioCollector {
      onStreamFinished: phone.news.newsOnResult(this.text)
    }

    onExited: (code, status) => phone.news.newsOnExit()
  }
}

