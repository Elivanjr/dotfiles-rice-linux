// core/AppRegistry.qml — catálogo único de apps internos e roteamento para suas telas.

import Quickshell
import "."

Scope {
  id: self

  required property var phone

  property list<AppDescriptor> apps: [
    AppDescriptor {
      appId: "menu"
      viewId: "menu"
      logic: phone.menu
      name: "Menu"
      capturesKeys: true
    },
    AppDescriptor {
      appId: "music"
      viewId: "music"
      logic: phone.music
      name: "Música"
      glyph: "note"
      glyphSize: 19
      tileColor: phone.noteBg
      roundIcon: true
      keywords: ["música", "musica", "music"]
      showInMenu: true
      capturesKeys: true
    },
    AppDescriptor {
      appId: "news"
      viewId: "news"
      logic: phone.news
      name: "Notícias"
      glyph: "file"
      tileColor: "#397bb8"
      keywords: ["notícias", "noticias", "news", "rss"]
      showInMenu: true
      capturesKeys: true
    },
    AppDescriptor {
      appId: "wallpaper"
      viewId: "wall"
      logic: phone.walls
      name: "Wallpaper"
      glyph: "image"
      tileColor: "#e8c25a"
      glyphColor: "#2a3340"
      keywords: ["wallpaper", "papel de parede", "fundo"]
      showInMenu: true
      capturesKeys: true
      enterAction: function () { phone.walls.refreshWalls(); }
    },
    AppDescriptor {
      appId: "files"
      viewId: "files"
      logic: phone.files
      name: "Meus arquivos"
      glyph: "folder"
      tileColor: "#4a9fe0"
      keywords: ["meus arquivos", "arquivos", "files", "pastas"]
      showInMenu: true
      capturesKeys: true
      enterAction: function () { phone.files.listDir(phone.files.filesDir); }
    },
    AppDescriptor {
      appId: "focus"
      viewId: "foco"
      logic: phone.foco
      name: "Foco"
      glyph: "timer"
      tileColor: "#e0554a"
      keywords: ["foco", "pomodoro", "timer", "tempo"]
      showInMenu: true
      capturesKeys: true
    },
    AppDescriptor {
      appId: "settings"
      viewId: "settings"
      logic: phone.config
      name: "Configurações"
      glyph: "gear"
      tileColor: "#6b7d8f"
      keywords: ["configurações", "configuracoes", "ajustes", "wifi", "wi-fi", "bluetooth", "bateria", "tema", "tela", "compartilhar", "idioma", "teclado", "sobre"]
      showInMenu: true
      capturesKeys: true
      enterAction: function () { phone.config.setEnter(); }
    },
    AppDescriptor {
      appId: "ssh"
      viewId: "ssh"
      logic: phone.ssh
      name: "SSH"
      glyph: "terminal"
      tileColor: "#3f9a77"
      keywords: ["ssh", "túnel", "tunel", "terminal", "remoto"]
      showInMenu: true
      capturesKeys: true
      enterAction: function () { phone.ssh.sshEnter(); }
    },
    AppDescriptor {
      appId: "schedule"
      viewId: "sched"
      logic: phone.sched
      name: "Agendar"
      glyph: "calendar"
      tileColor: "#8a6fd1"
      keywords: ["agendar", "agenda", "at", "programar", "lembrete", "comando"]
      showInMenu: true
      capturesKeys: true
      enterAction: function () { phone.sched.schedEnter(); }
    },
    AppDescriptor {
      appId: "downloader"
      viewId: "dl"
      logic: phone.dl
      name: "Baixar"
      glyph: "download"
      tileColor: "#2f9e8f"
      keywords: ["baixar", "download", "youtube", "yt-dlp", "video", "vídeo"]
      showInMenu: true
      capturesKeys: true
    },
    AppDescriptor {
      appId: "clipboard"
      viewId: "clip"
      logic: phone.clip
      name: "Clipboard"
      glyph: "clipboard"
      tileColor: "#d9822b"
      keywords: ["clipboard", "cliphist", "area de transferencia", "área de transferência", "copiar", "colar", "historico"]
      showInMenu: true
      capturesKeys: true
      enterAction: function () { phone.clip.clipEnter(); }
    },
    AppDescriptor {
      appId: "ai"
      viewId: "ai"
      logic: phone.ai
      name: "IA"
      glyph: "chat"
      tileColor: "#e08a3c"
      keywords: ["ia", "ai", "ollama", "chat", "conversa", "assistente"]
      showInMenu: true
      capturesKeys: true
      enterAction: function () { phone.ai.aiEnter(); }
    },
    AppDescriptor {
      appId: "calculator"
      viewId: "calc"
      logic: phone.calc
      name: "Calculadora"
      glyph: "calc"
      tileColor: "#2fa4a0"
      keywords: ["calculadora", "calc", "contas", "matemática"]
      showInMenu: true
      capturesKeys: true
    },
    AppDescriptor {
      appId: "snake"
      viewId: "snake"
      logic: phone.snake
      name: "Cobrinha"
      glyph: "snake"
      tileColor: "#4f9b5b"
      keywords: ["cobrinha", "snake", "jogo", "game"]
      showInMenu: true
      capturesKeys: true
      enterAction: function () { phone.snake.snakeEnter(); }
    },
    AppDescriptor {
      appId: "chat"
      viewId: "chat"
      logic: phone.chat
      name: "Chat"
      glyph: "chat"
      tileColor: "#3d7bd9"
      keywords: ["mensagens", "socket", "aparelho", "tcp"]
      showInMenu: true
      capturesKeys: true
    },
    AppDescriptor {
      appId: "share"
      viewId: "share"
      logic: phone.share
      name: "Compartilhar tela"
      capturesKeys: true
      enterAction: function () {
        phone.share.shareStep = "mode";
        phone.share.shareSel = 0;
        phone.share.shareStatus = "";
        phone.share.refreshShare();
      }
    },
    AppDescriptor {
      appId: "info"
      viewId: "info"
      logic: phone.info
      name: "Informações"
      capturesKeys: true
      enterAction: function () { phone.info.refreshInfo(); }
    }
  ]

  readonly property var keyApps: {
    const ids = [];
    for (let i = 0; i < apps.length; i++) {
      if (apps[i].capturesKeys)
        ids.push(apps[i].viewId);
    }
    return ids;
  }

  function appById(id) {
    for (let i = 0; i < apps.length; i++) {
      if (apps[i].appId === id)
        return apps[i];
    }

    return null;
  }

  function activeApp() {
    for (let i = 0; i < apps.length; i++) {
      if (apps[i].viewId === phone.view)
        return apps[i];
    }

    return null;
  }

  function capturesKeys(viewId) {
    return keyApps.indexOf(viewId) >= 0;
  }

  function appForView(viewId) {
    for (let i = 0; i < apps.length; i++) {
      if (apps[i].viewId === viewId)
        return apps[i];
    }

    return null;
  }

  function open(id) {
    const app = appById(id);
    if (!app)
      return false;

    if (app.appId === "files")
      phone.files.openFiles(false);
    else if (app.viewId)
      phone.view = app.viewId;

    return true;
  }

  function enterActive() {
    const app = activeApp();
    if (app && typeof app.enterAction === "function")
      app.enterAction();
  }
}
