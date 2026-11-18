// core/AppMenu.qml — Grade de apps (drun), busca, paginação, apps escondidos, popup de opções
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "menu".
// Acesso de fora:  phone.menu.<membro>

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // ================================================================
  // MENU / DRUN
  // ================================================================

  property string query: ""

  property int selected: 0

  property bool optionsOpen: false

  property int optSel: 0

  onOptionsOpenChanged: {
    if (optionsOpen)
      optSel = 0;
  }

  readonly property var optLabels: [
    "Música",
    "Wallpaper",
    "Meus arquivos",
    "Foco",
    "Configurações",
    "SSH",
    "IA",
    "Próxima página",
    showAllApps ? "Esconder utilitários" : "Mostrar todos os apps",
    "Fechar celular"
  ]

  readonly property string softLeftText: "Opções"
  readonly property string softCenterText: "Selecionar"
  readonly property string softRightText: "Voltar"

  function handleKey(e) {
    if (optionsOpen) {
      handleOptKey(e);
      return;
    }

    switch (e.key) {
    case Qt.Key_Escape:
      if (query !== "")
        query = "";
      else
        phone.panelOpen = false;
      break;
    case Qt.Key_Left:  move(-1); break;
    case Qt.Key_Right: move(1); break;
    case Qt.Key_Up:    move(-4); break;
    case Qt.Key_Down:  move(4); break;
    case Qt.Key_Return:
    case Qt.Key_Enter:
      launchSelected();
      break;
    case Qt.Key_Backspace:
      query = query.slice(0, -1);
      break;
    default:
      if (e.text && e.text.length === 1 && e.text >= " ")
        query += e.text;
      else
        return;
    }

    e.accepted = true;
  }

  function softLeft() { optionsOpen = !optionsOpen; }

  function softCenter() {
    if (optionsOpen)
      optRun(optSel);
    else
      launchSelected();
  }

  function softRight() {
    if (optionsOpen)
      optionsOpen = false;
    else if (query !== "")
      query = "";
    else
      phone.panelOpen = false;
  }

  function optRun(i) {
    optionsOpen = false;

    if (i === 0)
      phone.registry.open("music");
    else if (i === 1)
      phone.registry.open("wallpaper");
    else if (i === 2)
      phone.registry.open("files");
    else if (i === 3)
      phone.registry.open("focus");
    else if (i === 4)
      phone.registry.open("settings");
    else if (i === 5)
      phone.registry.open("ssh");
    else if (i === 6)
      phone.registry.open("ai");
    else if (i === 7)
      nextPage();
    else if (i === 8)
      showAllApps = !showAllApps;
    else
      phone.panelOpen = false;
  }

  // teclado dentro do menu Opções (setas, Enter, Esc)
  function handleOptKey(e) {
    const n = optLabels.length;

    switch (e.key) {
    case Qt.Key_Up:    optSel = (optSel + n - 1) % n; break;
    case Qt.Key_Down:  optSel = (optSel + 1) % n;     break;

    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Right:
      optRun(optSel);
      break;

    case Qt.Key_Escape:
    case Qt.Key_Left:
      optionsOpen = false;
      break;

    default:
      return;
    }

    e.accepted = true;
  }

  readonly property int perPage: 16

  readonly property int page: Math.floor(selected / perPage)

  readonly property int pageCount:
    Math.max(1, Math.ceil(menuItems.length / perPage))

  // ---------------- apps escondidos do menu ----------------
  //
  // Cada item é uma regex (sem diferenciar maiúsculas).
  //   hideNames: testa o nome que aparece no menu (já traduzido)
  //   hideIds:   testa o id do .desktop (não muda com o idioma)
  //
  // Pra ver o que está escondido e o id de cada app:
  //   qs -c phone ipc call phone apps
  // Pra rever tudo no próprio celular: Opções > Mostrar todos os apps

  property bool showAllApps: false

  readonly property var hideNames: [
    // calculadoras do sistema (o celular tem a própria)
    "^(calculadora|calculator)$",

    // módulos soltos das configurações do KDE/Plasma
    "^(access prompt|account authentication|animations|application style|autostart|colors|connection preferences|customize look and feel|day-night cycle|default applications|desktop effects|desktop shell scripting console|file associations|file search|file type editor|font management|fonts|global theme|icons|keyboard layout|night light|night time service|notifications|online accounts|plasma style|pointers|proxy|region & language|screen locking|system sounds|task switcher|terminal preferences|user feedback|user folders update|users|virtual desktops|web search keywords|window behavior|window decorations|window rules)$",
    "^(breeze|darkly)",

    // helpers e diálogos do KDE
    "^(kded|kdialog|kio|ktelnetservice|kfontinst|kfontview|kcolorschemeeditor|knewstuff|klipper)",
    "^kde wallet",
    "^kwin",
    "^plasma",

    // demos e ferramentas de GTK / GNOME / MATE / X11
    "^(about mate|mate color selection|gtk[+] demo|gtk settings|granite|icon browser|widget factory|hardware locality|geoclue|where am i|pinentry|secret prompter|policykit|zenity|yad|xdvi|xgps|legacy x11|xwayland)",

    // ferramentas de desenvolvimento do Qt
    "^qt( |[0-9])",

    // Wine / Proton (dependências)
    "protontricks",
    "winetricks",
    "^wine ",
    "^(a wine application|rundll32|winhlp32|wscript)",

    // Java
    "^openjdk",

    // utilitários e atalhos auxiliares
    "^rofi",
    "^flatpak (install|remove|update)",
    "url (handler|launcher)",
    "^(networkmanager applet|bluetooth adapters|shelly notifications|virtual keyboard|cmake|quickshell)$"
  ]

  readonly property var hideIds: [
    "^kcm",
    "^(kded|kio|kwin|kdialog|klipper|kfontinst|kfontview|kcolorschemeeditor|knewstuff|ktelnetservice)",
    "^org[.]kde[.](kwalletd|kded|kio|kdialog|klipper|kfontview|kfontinst|kcolorschemeeditor|knewstuff|ktelnetservice|plasma|kwin)",
    "^(protontricks|winetricks|wine|rofi|blueman-adapters|nm-applet|designer|assistant|linguist|qdbusviewer|qv4l2|qvidcap|xdvi|lstopo|xgps|cmake-gui|pinentry|zenity|yad)",
    "openjdk|jconsole|jshell",
    "^(gtk3|gtk4)-(demo|icon-browser|widget-factory)",
    "^org[.]gtk[.](gtk[34]demo|iconbrowser[34]|widgetfactory[34]|demo)"
  ]

  readonly property var hideNameRe: hideNames.map(function (p) {
    return new RegExp(p, "i");
  })

  readonly property var hideIdRe: hideIds.map(function (p) {
    return new RegExp(p, "i");
  })

  function isHiddenApp(e, ignoreToggle) {
    if (showAllApps && !ignoreToggle)
      return false;

    const name = e.name || "";
    const id = e.id || "";

    for (let i = 0; i < hideNameRe.length; i++) {
      if (hideNameRe[i].test(name))
        return true;
    }

    for (let j = 0; j < hideIdRe.length; j++) {
      if (hideIdRe[j].test(id))
        return true;
    }

    return false;
  }

  readonly property var allEntries: {
    const out = [];
    const list = DesktopEntries.applications.values;

    for (let i = 0; i < list.length; i++) {
      if (!list[i].noDisplay && !isHiddenApp(list[i], false))
        out.push(list[i]);
    }

    out.sort(function (a, b) {
      return a.name.localeCompare(b.name);
    });

    return out;
  }

  // Apps do celular (Música, Calculadora, Agendar…) e apps reais (.desktop) ficam
  // na mesma lista, em ordem alfabética pelo nome.
  readonly property var menuItems: {
    const q = query.toLowerCase();
    const items = [];
    const internalApps = phone.registry.apps;

    for (let i = 0; i < internalApps.length; i++) {
      const app = internalApps[i];
      if (!app.showInMenu)
        continue;

      let matches = q === "" || app.name.toLowerCase().indexOf(q) >= 0;
      for (let j = 0; !matches && j < app.keywords.length; j++)
        matches = app.keywords[j].toLowerCase().indexOf(q) >= 0;

      if (matches)
        items.push(app);
    }

    const real = [];
    for (let i = 0; i < allEntries.length; i++) {
      const entry = allEntries[i];
      if (q !== "") {
        const hay = (
          entry.name + " " +
          (entry.genericName || "") + " " +
          (entry.keywords ? entry.keywords.join(" ") : "")
        ).toLowerCase();

        if (hay.indexOf(q) < 0)
          continue;
      }

      real.push({ name: entry.name, icon: entry.icon, desktopEntry: entry });
    }

    const all = real.concat(items);
    all.sort(function (a, b) {
      return a.name.localeCompare(b.name);
    });

    return all;
  }

  readonly property string selectedName:
    menuItems.length > 0 && menuItems[selected]
      ? menuItems[selected].name
      : ""

  onMenuItemsChanged: {
    selected = Math.max(0, Math.min(selected, menuItems.length - 1));
  }

  onQueryChanged: selected = 0

  function move(delta) {
    const n = menuItems.length;

    if (n === 0)
      return;

    selected = Math.max(0, Math.min(n - 1, selected + delta));
  }

  function nextPage() {
    const n = menuItems.length;

    if (n === 0)
      return;

    const target = (page + 1) * perPage;
    selected = target >= n ? 0 : target;
  }

  function launch(item) {
    if (!item)
      return;

    if (item.appId) {
      phone.registry.open(item.appId);
      return;
    }

    if (item.desktopEntry)
      item.desktopEntry.execute();

    phone.panelOpen = false;
  }

  function launchSelected() {
    launch(menuItems[selected]);
  }

  function resolveIcon(icon) {
    if (!icon || icon === "")
      return "";

    if (icon.startsWith("file://") || icon.startsWith("image://"))
      return icon;

    if (icon.startsWith("/"))
      return "file://" + icon;

    return Quickshell.iconPath(icon, "application-x-executable");
  }
}
