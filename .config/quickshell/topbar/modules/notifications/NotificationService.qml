// NotificationService.qml — serviço de notificações nativo do Quickshell,
// ISOLADO do shell.qml (singleton, mesmo padrão do Colors.qml — qualquer
// arquivo na mesma pasta usa "NotificationService.xxx" sem precisar de
// import nem de o shell.qml saber que isso existe).
//
// Ver o resumo de pré-requisitos e passos de integração na resposta do
// chat — este arquivo sozinho não muda nada no seu sistema até você:
//   1. desativar o SwayNC (ver texto),
//   2. instanciar NotificationCenter.qml/NotificationToasts.qml em algum
//      lugar (hoje eles não são carregados por ninguém).
//
// Arquitetura (por quê popups e histórico são coisas separadas):
// um objeto Notification que já foi fechado (dismiss/expire) fica destruído
// de verdade — se um array ainda tiver uma referência viva pra ele quando
// uma ListView tentar renderizar, o Quickshell trava (segfault confirmado
// num relato de outro projeto que usa essa mesma API do Quickshell 0.3.1).
// Por isso:
//   - activeNotifications: objetos Notification VIVOS, só pros popups.
//     Removido do array assim que a notificação fecha (sinal closed()).
//   - notifHistory: cópia dos DADOS (texto/ícone/hora), nunca o objeto —
//     sobrevive tranquilo depois que a notificação original já era.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
  id: service

  property var activeNotifications: []
  property var notifHistory: [] // [{id, appName, summary, body, appIcon, image, urgency, time}]
  readonly property int notifHistoryLimit: 100
  property bool dndEnabled: false

  NotificationServer {
    id: notifServer
    keepOnReload: false
    bodySupported: true
    bodyMarkupSupported: true
    imageSupported: true
    actionsSupported: true
    persistenceSupported: true

    onNotification: (notification) => {
      notification.tracked = true;

      notification.closed.connect(function (reason) {
        service.activeNotifications = service.activeNotifications.filter(n => n !== notification);
      });

      service.notifHistory = [{
        id: notification.id,
        appName: notification.appName || "Sistema",
        summary: notification.summary || "",
        body: notification.body || "",
        appIcon: notification.appIcon || "",
        image: notification.image || "",
        urgency: notification.urgency,
        time: new Date().toLocaleTimeString(Qt.locale(), "HH:mm")
      }].concat(service.notifHistory).slice(0, service.notifHistoryLimit);

      if (!service.dndEnabled) {
        service.activeNotifications = [notification].concat(service.activeNotifications);
        const timeoutMs = notification.expireTimeout > 0 ? notification.expireTimeout * 1000 : 5000;
        notifAutoExpire.createObject(service, { notification: notification, timeoutMs: timeoutMs });
      }
    }
  }

  // um Timer descartável por notificação — expira o toast sozinho depois
  // do tempo certo, sem precisar de um Timer fixo por slot
  Component {
    id: notifAutoExpire
    Timer {
      required property var notification
      required property real timeoutMs
      interval: timeoutMs
      running: true
      onTriggered: {
        if (notification && notification.tracked) notification.expire();
        destroy();
      }
    }
  }

  // ---------- ponte com o processo do lockscreen ----------
  // "lockscreen" roda com `qs -c lockscreen`, um processo Quickshell
  // separado do "topbar" de propósito (se um crashar, o outro continua) —
  // por isso não compartilha esse singleton. A ponte é só arquivo:
  //   notif-bridge.json  (topbar escreve, lockscreen lê)   -> notificações ativas
  //   notif-dismiss.json (lockscreen escreve, topbar lê)   -> pedidos de dismiss
  readonly property string bridgeDir: (Quickshell.env("HOME") || "/tmp") + "/.cache/quickshell"

  Process {
    id: bridgeDirMaker
    command: ["mkdir", "-p", service.bridgeDir]
    running: true
  }

  FileView {
    id: bridgeOutFile
    path: service.bridgeDir + "/notif-bridge.json"
    watchChanges: false // só o topbar escreve aqui
    onAdapterUpdated: writeAdapter() // sem isso, mudar a propriedade não persiste nada
    JsonAdapter {
      id: bridgeOut
      property var notifications: []
    }
  }

  function _syncBridgeOut() {
    bridgeOut.notifications = service.activeNotifications.map(n => ({
      id: n.id,
      appName: n.appName || "Sistema",
      summary: n.summary || "",
      body: n.body || "",
      appIcon: n.appIcon || "",
      image: n.image || "",
      urgency: n.urgency
    }));
  }
  onActiveNotificationsChanged: service._syncBridgeOut()

  FileView {
    id: bridgeInFile
    path: service.bridgeDir + "/notif-dismiss.json"
    watchChanges: true
    onFileChanged: reload()
    JsonAdapter {
      id: bridgeIn
      property var pending: []
      onPendingChanged: service._processBridgeDismisses()
    }
  }

  function _processBridgeDismisses() {
    if (!bridgeIn.pending || bridgeIn.pending.length === 0) return;
    for (const id of bridgeIn.pending) {
      const notif = service.activeNotifications.find(n => n.id === id);
      if (notif) service.dismissNotification(notif);
    }
    bridgeIn.pending = [];
  }

  function clearNotifHistory() {
    service.notifHistory = [];
  }

  function dismissNotification(notification) {
    if (notification && notification.tracked) notification.dismiss();
  }

  // ---------- toast especial de "tocando agora" (só Spotify) ----------
  // separado de propósito de activeNotifications/notifHistory: não é uma
  // notificação real vinda do D-Bus, é gerada por nós quando a faixa muda
  // (ver shell.qml). Nunca entra no notifHistory — não deve aparecer na
  // central, só o popup de 7s.
  property var mediaToasts: [] // [{id, title, artist, artUrl}]

  function pushMediaToast(title, artist, artUrl) {
    const id = Date.now() + "-" + Math.random();
    service.mediaToasts = service.mediaToasts.concat([{
      id: id, title: title, artist: artist, artUrl: artUrl
    }]);
    mediaToastExpire.createObject(service, { toastId: id });
  }

  Component {
    id: mediaToastExpire
    Timer {
      required property string toastId
      interval: 7000
      running: true
      onTriggered: {
        service.mediaToasts = service.mediaToasts.filter(t => t.id !== toastId);
        destroy();
      }
    }
  }
}
