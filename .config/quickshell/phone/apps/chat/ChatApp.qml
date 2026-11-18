// apps/chat/ChatApp.qml — Chat entre dois aparelhos por socket TCP (sem SSH)
//
// Lógica do app, instanciada em shell.qml como "chat".
// Acesso de fora:  phone.chat.<membro>
// Tela: ChatView.qml | Helper: helper/chat-helper.py
//
// Um aparelho escolhe "Ouvir" (fica esperando na porta) e o outro escolhe
// "Conectar" e digita o IP do primeiro. Os dois precisam estar na mesma rede.
// Protocolo: uma linha JSON {"m": "texto"} por mensagem.
// Sem senha: use só em rede de casa / confiável.

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // "setup" (escolher modo) ou "chat" (conversa)
  property string chatScreen: "setup"

  // "listen" | "connect"
  property string chatMode: "listen"

  property string chatHost: ""

  property string chatPort: "5055"

  // linha selecionada na tela de configuração: 0 modo, 1 IP, 2 porta, 3 iniciar
  property int chatRow: 0

  // texto de estado (aparece no subtítulo)
  property string chatStatus: "parado"

  property bool chatConnected: false

  property string chatInput: ""

  // mensagens: { who: "me" | "peer" | "sys", txt: string }
  property alias chatModel: chatMsgs

  readonly property string chatSoftLeft: chatScreen === "chat" ? "Limpar" : ""

  readonly property string chatSoftCenter: chatScreen === "chat" ? "Enviar" : "Iniciar"

  readonly property string softLeftText: chatSoftLeft

  readonly property string softCenterText: chatSoftCenter

  readonly property string softRightText: "Voltar"

  readonly property string helperPath:
    decodeURIComponent(String(Qt.resolvedUrl("helper/chat-helper.py")).replace("file://", ""))

  ListModel {
    id: chatMsgs
  }

  // ---------------- helper (python) ----------------

  Process {
    id: chatProc

    stdinEnabled: true

    stdout: SplitParser {
      onRead: (data) => self.chatOnLine(data)
    }

    stderr: SplitParser {
      onRead: (data) => self.chatAdd("sys", data)
    }

    onExited: (code, status) => self.chatOnExit()
  }

  // colar (Ctrl+V) joga o texto do clipboard no campo de mensagem
  Process {
    id: chatPasteProc

    command: ["wl-paste", "-n", "-t", "text"]

    stdout: StdioCollector {
      onStreamFinished: self.chatPaste(this.text)
    }
  }

  function chatOnLine(data) {
    let ev = null;

    try {
      ev = JSON.parse(data);
    } catch (err) {
      return;
    }

    if (ev.t === "status")
      chatOnStatus(ev.v);
    else if (ev.t === "msg")
      chatAdd("peer", ev.v);
    else if (ev.t === "erro")
      chatAdd("sys", ev.v);
  }

  function chatOnStatus(v) {
    chatStatus = v;

    if (v.indexOf("conectado a") === 0) {
      chatConnected = true;
      chatAdd("sys", v);
    } else if (v === "desconectado") {
      chatConnected = false;
      chatAdd("sys", v);
    } else if (v.indexOf("falhou") === 0) {
      chatConnected = false;
      chatAdd("sys", v);
    }
  }

  function chatOnExit() {
    chatConnected = false;

    // saiu da conversa de propósito: a tela já é a de configuração
    if (chatScreen === "chat")
      chatStatus = "encerrado";
  }

  function chatAdd(who, txt) {
    if (chatMsgs.count > 300)
      chatMsgs.remove(0, 60);

    chatMsgs.append({ who: who, txt: String(txt) });
  }

  // ---------------- iniciar / parar ----------------

  function chatStart() {
    if (chatProc.running)
      return;

    const porta = parseInt(chatPort, 10);

    if (!(porta > 0 && porta < 65536)) {
      chatStatus = "porta inválida";
      return;
    }

    if (chatMode === "listen") {
      chatProc.command = ["python3", helperPath, "listen", String(porta)];
    } else {
      const host = chatHost.trim();

      if (host === "") {
        chatStatus = "digite o IP do outro aparelho";
        return;
      }

      chatProc.command = ["python3", helperPath, "connect", host, String(porta)];
    }

    chatMsgs.clear();
    chatInput = "";
    chatConnected = false;
    chatScreen = "chat";
    chatStatus = "iniciando…";
    chatProc.running = true;
  }

  function chatStop() {
    chatConnected = false;

    if (chatProc.running)
      chatProc.running = false;
  }

  // Esc / Voltar: na conversa volta para a configuração; na configuração sai do app
  function chatBack() {
    if (chatScreen === "chat") {
      chatScreen = "setup";
      chatStop();
      chatStatus = "parado";
    } else {
      phone.view = "menu";
    }
  }

  // ---------------- enviar ----------------

  function chatSend() {
    const txt = chatInput.trim();

    if (txt === "")
      return;

    if (!chatConnected) {
      chatAdd("sys", "ainda sem conexão");
      return;
    }

    chatProc.write(JSON.stringify({ m: txt }) + "\n");
    chatAdd("me", txt);
    chatInput = "";
  }

  function chatPaste(t) {
    chatInput += String(t).replace(/[\r\n]+/g, " ");
  }

  // ---------------- teclado ----------------

  function handleChatKey(e) {
    if (chatScreen === "chat")
      chatConversaKey(e);
    else
      chatSetupKey(e);
  }

  function handleKey(e) {
    handleChatKey(e);
  }

  function chatConversaKey(e) {
    const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;

    if (ctrl && e.key === Qt.Key_V) {
      chatPasteProc.running = true;
      e.accepted = true;
      return;
    }

    switch (e.key) {
    case Qt.Key_Escape:
      chatBack();
      break;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      chatSend();
      break;

    case Qt.Key_Backspace:
      chatInput = chatInput.slice(0, -1);
      break;

    default:
      if (e.text && e.text.length === 1 && e.text >= " ")
        chatInput += e.text;
      else
        return;
    }

    e.accepted = true;
  }

  function chatSetupKey(e) {
    const digito = e.text && e.text.length === 1 && e.text >= "0" && e.text <= "9";
    const imprimivel = e.text && e.text.length === 1 && e.text >= " ";

    switch (e.key) {
    case Qt.Key_Escape:
      chatBack();
      break;

    case Qt.Key_Up:
      chatRow = (chatRow + 3) % 4;
      break;

    case Qt.Key_Down:
      chatRow = (chatRow + 1) % 4;
      break;

    case Qt.Key_Left:
    case Qt.Key_Right:
      if (chatRow !== 0)
        return;

      chatMode = chatMode === "listen" ? "connect" : "listen";
      break;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      chatStart();
      break;

    case Qt.Key_Backspace:
      if (chatRow === 1)
        chatHost = chatHost.slice(0, -1);
      else if (chatRow === 2)
        chatPort = chatPort.slice(0, -1);
      else
        return;
      break;

    default:
      if (chatRow === 1 && chatMode === "connect" && imprimivel)
        chatHost += e.text;
      else if (chatRow === 2 && digito && chatPort.length < 5)
        chatPort += e.text;
      else
        return;
    }

    e.accepted = true;
  }

  // ---------------- softkeys ----------------

  function softLeft() {
    if (chatScreen === "chat")
      chatMsgs.clear();
  }

  function softCenter() {
    if (chatScreen === "chat")
      chatSend();
    else
      chatStart();
  }

  function softRight() {
    chatBack();
  }
}
