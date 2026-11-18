// system/settings/SettingsApp.qml — Configurações e roteamento das seções
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "config".
// Acesso de fora:  phone.config.<membro>

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  readonly property BluetoothSettings bluetooth: BluetoothSettings {
    id: bluetoothModule
    settings: self
  }
  readonly property HotspotSettings hotspot: HotspotSettings {
    id: hotspotModule
    settings: self
  }
  readonly property WifiSettings wifi: WifiSettings {
    id: wifiModule
    settings: self
  }

  // item da view registrado por ela mesma (Binding em SettingsView.qml)
  property var setListRef: null

  // ================================================================
  // CONFIGURAÇÕES
  //
  // Seções: Wi-Fi (com ponto de acesso), Bluetooth, Bateria, Temas, Telas
  // (com o app de compartilhar tela), Local, Idioma e Teclado, Sobre.
  // Tudo roda por comandos do sistema (nmcli, bluetoothctl, powerprofilesctl,
  // timedatectl, localectl, hyprctl). O tema só afeta o celular.
  // ================================================================

  property string setPage: "home"

  property int setSel: 0

  property string setStatus: ""

  property bool setBusy: false

  property string setActOk: ""

  property bool setKeep: false              // volta de share/foto sem resetar a página

  property string avatarReturn: "info"

  readonly property var setOrder: ["wifi", "bluetooth", "battery", "theme", "screens", "location", "lang", "about"]

  // salvos em disco
  property alias hotspotSsid: hotspotModule.ssid
  property alias hotspotPass: hotspotModule.password

  // wifi
  property alias setWifiOn: wifiModule.radioOn
  property alias setNets: wifiModule.networks

  property alias setHotspotOn: hotspotModule.enabled

  property alias setNoNm: wifiModule.networkManagerMissing
  property alias setAp: wifiModule.accessPoint

  // bluetooth
  property alias setBtOn: bluetoothModule.powered
  property alias setBtScan: bluetoothModule.scanning
  property alias setBtDevs: bluetoothModule.devices
  property alias setBtRecv: bluetoothModule.receiving
  property alias setBtRecvLast: bluetoothModule.receivedFile
  property alias setBtSendMac: bluetoothModule.sendMac
  property alias setBtSendName: bluetoothModule.sendName

  // bateria
  property string setProfile: ""

  property var setProfiles: []

  property var setBatUp: ({})

  // telas
  property var setMons: []

  // local
  property string setTz: ""

  property string setNtp: ""

  property string setNtpSync: ""

  property string setClock: ""

  property var setIp: ({})

  property bool setIpBusy: false

  // idioma e teclado
  property string setLocale: Quickshell.env("LANG") || ""

  property string setVc: ""

  property string setKbLayout: ""

  property string setKbVariant: ""

  property string setKbActive: ""

  property var setLocales: []

  // imagens disponíveis para o wallpaper do celular (página Temas > Wallpaper)
  property var setWalls: []

  // pasta com as imagens de wallpaper do celular
  readonly property string setBgDir: phone.files.homeDir + "/Imagens/celularBG"

  // sobre
  property var setAbout: ({})

  // formulário (senha do Wi-Fi, ponto de acesso)
  property bool setForm: false

  property string setFormTitle: ""

  property string setFormHint: ""

  property string setFormAction: ""

  property string setFormCtx: ""

  property var setFormFields: []

  property int setFormFocus: 0

  property bool setOptOpen: false

  property int setOptSel: 0

  property string setInfoPage: ""

  readonly property string setFile:
    (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
    + "/quickshell-phone/settings.json"

  // ---------------- salvar / carregar ----------------

  function setSave() {
    const data = JSON.stringify({
      themeDark: phone.themeDark,
      celularBg: phone.celularBg,
      hotspotSsid: hotspotSsid,
      hotspotPass: hotspotPass
    });

    Quickshell.execDetached([
      "sh", "-c",
      'umask 077; mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"',
      "sh", setFile, data
    ]);
  }

  Timer {
    interval: 80
    running: true

    onTriggered: setLoadProc.running = true
  }

  Process {
    id: setLoadProc

    command: ["sh", "-c", 'cat "$1" 2>/dev/null', "sh", phone.config.setFile]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const j = JSON.parse(this.text);

          if (typeof j.themeDark === "boolean")
            phone.themeDark = j.themeDark;

          if (j.celularBg)
            phone.celularBg = j.celularBg;

          if (j.hotspotSsid)
            phone.config.hotspotSsid = j.hotspotSsid;

          if (j.hotspotPass)
            phone.config.hotspotPass = j.hotspotPass;
        } catch (e) {
          // sem arquivo ainda: fica no padrão
        }
      }
    }
  }

  // ---------------- textos ----------------

  readonly property var setTitles: ({
    home: "Configurações", wifi: "Wi-Fi", bluetooth: "Bluetooth", battery: "Bateria",
    theme: "Temas", screens: "Telas", location: "Local", lang: "Idioma e Teclado",
    locales: "Idioma", celularbg: "Wallpaper", about: "Sobre o Notebook"
  })

  readonly property var setHints: ({
    home: "Escolha uma seção",
    wifi: "Redes e compartilhar internet",
    bluetooth: "Dispositivos próximos",
    battery: "Carga e modo de energia",
    theme: "Só afeta o celular",
    screens: "Telas e compartilhamento",
    location: "Fuso horário e localização",
    lang: "Idioma do sistema e layout",
    locales: "Idioma do sistema",
    celularbg: "Fundo da tela do celular",
    about: "Informações do notebook"
  })

  readonly property string setWifiSummary: {
    if (phone.sys.wifiState === "off")
      return "Desligado";

    if (setHotspotOn)
      return "Ponto de acesso ativo";

    if (phone.sys.wifiState === "connected") {
      for (let i = 0; i < setNets.length; i++) {
        if (setNets[i].inuse)
          return setNets[i].ssid;
      }

      return "Conectado";
    }

    return phone.sys.ethUp ? "Cabo conectado" : "Desconectado";
  }

  readonly property string setBtSummary:
    phone.sys.btOn ? (phone.sys.btConnected ? "Conectado" : "Ligado") : "Desligado"

  readonly property string setBatSummary:
    phone.sys.batPct >= 0
      ? phone.sys.batPct + "%" + (phone.sys.batState === "Charging" ? " · carregando" : "")
      : "Sem bateria"

  readonly property string setScreensSummary: {
    const n = phone.share.shareMonitors.length + 1;

    return n + (n === 1 ? " tela" : " telas");
  }

  readonly property real setHeaderH:
    setPage === "battery" ? phone.s(60)
      : setPage === "screens" ? phone.s(90)
      : setPage === "theme" ? phone.s(64)
      : setPage === "about" ? phone.s(66)
      : 0

  // ---------------- linhas de cada página ----------------

  function setBatInfo(label, key) {
    const v = setBatUp[key];

    return v ? { k: "info", t: label, d: v, kind: "info" } : null;
  }

  readonly property var setRows: {
    const R = [];
    const p = setPage;

    if (p === "home") {
      R.push({ k: "go:wifi",      t: "Wi-Fi",            d: setWifiSummary,    kind: "nav", icon: "wifi",     ic: "#4a9fe0" });
      R.push({ k: "go:bluetooth", t: "Bluetooth",        d: setBtSummary,      kind: "nav", icon: "bluetooth", ic: "#4f7be0" });
      R.push({ k: "go:battery",   t: "Bateria",          d: setBatSummary,     kind: "nav", icon: "battery",  ic: "#5fae6a" });
      R.push({ k: "go:theme",     t: "Temas",            d: phone.themeDark ? "Escuro" : "Claro", kind: "nav", icon: "moon", ic: "#8a6fd6" });
      R.push({ k: "go:screens",   t: "Telas",            d: setScreensSummary, kind: "nav", icon: "monitor",  ic: "#e08a3c" });
      R.push({ k: "go:location",  t: "Local",            d: setTz !== "" ? setTz : "Fuso e localização", kind: "nav", icon: "pin", ic: "#d9608f" });
      R.push({ k: "go:lang",      t: "Idioma e Teclado", d: setLocale !== "" ? setLocale : "Idioma e layout", kind: "nav", icon: "keyboard", ic: "#3f9a77" });
      R.push({ k: "go:about",     t: "Sobre o Notebook", d: Quickshell.env("USER"), kind: "nav", icon: "about", ic: "#6b7d8f" });
    } else if (p === "wifi") {
      if (setNoNm) {
        R.push({ k: "info", t: "NetworkManager não encontrado", d: "Instale o nmcli para usar o Wi-Fi", kind: "info" });
      } else {
        R.push({ k: "wifi:toggle", t: "Wi-Fi", d: setWifiOn ? "Ligado" : "Desligado", kind: "toggle", on: setWifiOn });
        R.push({
          k: "hotspot:toggle", t: "Compartilhar internet",
          d: setHotspotOn ? "Ativo · " + hotspotSsid : setHotspotPlan.text,
          kind: "toggle", on: setHotspotOn
        });

        if (setHotspotOn) {
          R.push({ k: "info", t: "Conecte o celular em", d: hotspotSsid + " · senha: " + hotspotPass, kind: "info" });
          R.push({ k: "hotspot:qr", t: "Mostrar QR Code", d: "Aponte a câmera do celular", kind: "action" });
        }

        R.push({ k: "hotspot:cfg", t: "Nome e senha da rede", d: hotspotSsid !== "" ? hotspotSsid : "Ainda não configurada", kind: "nav" });

        if (setWifiOn) {
          for (let i = 0; i < setNets.length; i++) {
            const n = setNets[i];
            const open = n.sec === "" || n.sec === "--";

            R.push({
              k: "net:" + i, t: n.ssid,
              d: (n.inuse ? "Conectada · " : (n.saved ? "Salva · " : "")) + n.signal + "% · " + (open ? "aberta" : n.sec),
              kind: "net", on: n.inuse, sig: n.signal
            });
          }

          if (setNets.length === 0)
            R.push({ k: "info", t: "Nenhuma rede encontrada", d: "Opções > Atualizar redes", kind: "info" });
        }
      }
    } else if (p === "bluetooth") {
      R.push({ k: "bt:toggle", t: "Bluetooth", d: setBtOn ? "Ligado" : "Desligado", kind: "toggle", on: setBtOn });

      if (setBtOn) {
        R.push({ k: "bt:scan", t: setBtScan ? "Buscando dispositivos…" : "Buscar dispositivos", d: "", kind: "action" });

        R.push({
          k: "bt:recv", t: "Receber arquivos",
          d: setBtRecv
            ? (setBtRecvLast !== "" ? "Recebido: " + setBtRecvLast : "Visível · salvando em Downloads/Bluetooth")
            : "Deixa o notebook visível para receber",
          kind: "toggle", on: setBtRecv
        });

        for (let i = 0; i < setBtDevs.length; i++) {
          const d = setBtDevs[i];

          R.push({
            k: "dev:" + i, t: d.name !== "" ? d.name : d.mac,
            d: d.connected
              ? "Conectado" + (d.battery >= 0 ? " · " + d.battery + "%" : "")
              : (d.paired ? "Pareado" : "Disponível"),
            kind: "dev", on: d.connected
          });
        }
      }
    } else if (p === "battery") {
      if (setProfiles.length > 0) {
        const names = {
          "power-saver": ["Economia de energia", "Dura mais, desempenho menor"],
          "balanced": ["Equilibrado", "Equilíbrio entre energia e desempenho"],
          "performance": ["Desempenho", "Máximo desempenho, gasta mais"]
        };

        for (const pr of ["power-saver", "balanced", "performance"]) {
          if (setProfiles.indexOf(pr) >= 0)
            R.push({ k: "prof:" + pr, t: names[pr][0], d: names[pr][1], kind: "radio", on: setProfile === pr });
        }
      } else {
        R.push({ k: "info", t: "Modos de energia indisponíveis", d: "Instale o power-profiles-daemon", kind: "info" });
      }

      R.push({ k: "info", t: "Estado", d: phone.sys.batState === "Charging" ? "Carregando" : (phone.sys.batState === "Full" ? "Carga completa" : (phone.sys.batState === "Discharging" ? "Usando a bateria" : (phone.sys.batState || "--"))), kind: "info" });

      const t1 = setBatInfo("Tempo para esvaziar", "time to empty");
      const t2 = setBatInfo("Tempo para carregar", "time to full");
      const t3 = setBatInfo("Consumo", "energy-rate");
      const t4 = setBatInfo("Saúde da bateria", "capacity");

      if (t1) R.push(t1);
      if (t2) R.push(t2);
      if (t3) R.push(t3);
      if (t4) R.push(t4);
    } else if (p === "theme") {
      R.push({ k: "theme:dark",  t: "Escuro", d: "Fundo escuro no celular", kind: "radio", on: phone.themeDark });
      R.push({ k: "theme:light", t: "Claro",  d: "Fundo claro no celular",  kind: "radio", on: !phone.themeDark });
      R.push({ k: "go:celularbg", t: "Wallpaper do celular", d: phone.walls.baseName(phone.celularBg), kind: "nav" });
      R.push({ k: "info", t: "Só o celular", d: "O tema do sistema não muda", kind: "info" });
    } else if (p === "screens") {
      for (let i = 0; i < setMons.length; i++) {
        const m = setMons[i];
        const mir = m.mirrorOf && m.mirrorOf !== "none";

        R.push({
          k: "info", t: m.name,
          d: m.width + "x" + m.height + "@" + Math.round(m.refreshRate || 0) + "Hz"
            + (m.disabled ? " · desligada" : (mir ? " · espelhando" : ""))
            + ((m.scale && m.scale !== 1) ? " · " + Math.round(m.scale * 100) + "%" : ""),
          kind: "info"
        });
      }

      R.push({
        k: "share", t: "Compartilhar tela",
        d: phone.share.shareHasExt ? "Unir ou espelhar com " + phone.share.shareMonitors[0].name : "Conecte uma tela externa",
        kind: "nav"
      });
    } else if (p === "location") {
      R.push({ k: "info", t: "Fuso horário", d: setTz !== "" ? setTz : "--", kind: "info" });
      R.push({ k: "info", t: "Data e hora", d: setClock !== "" ? setClock : "--", kind: "info" });
      R.push({
        k: "ntp:toggle", t: "Hora automática",
        d: setNtp === "yes" ? (setNtpSync === "yes" ? "Sincronizada" : "Sincronizando…") : "Desligada",
        kind: "toggle", on: setNtp === "yes"
      });
      R.push({
        k: "loc:detect", t: setIpBusy ? "Detectando…" : "Detectar localização",
        d: "Aproximada, pelo seu IP", kind: "action"
      });

      if (setIp.city) {
        R.push({ k: "info", t: "Cidade", d: setIp.city + (setIp.region ? " · " + setIp.region : ""), kind: "info" });
        R.push({ k: "info", t: "País", d: setIp.country || "--", kind: "info" });
        R.push({ k: "info", t: "Coordenadas", d: setIp.loc || "--", kind: "info" });
        R.push({ k: "info", t: "Provedor", d: setIp.org || "--", kind: "info" });

        if (setIp.timezone && setIp.timezone !== setTz)
          R.push({ k: "loc:tz", t: "Usar fuso " + setIp.timezone, d: "Trocar o fuso do sistema", kind: "action" });
      } else if (setIp.error) {
        R.push({ k: "info", t: "Não consegui detectar", d: setIp.error, kind: "info" });
      }
    } else if (p === "lang") {
      R.push({ k: "go:locales", t: "Idioma do sistema", d: setLocale !== "" ? setLocale : "--", kind: "nav" });
      R.push({ k: "info", t: "Teclado do console", d: setVc !== "" ? setVc : "--", kind: "info" });
      R.push({ k: "info", t: "Layout ativo", d: setKbActive !== "" ? setKbActive : "--", kind: "info" });

      const ls = setKbLayout !== "" ? setKbLayout.split(",") : [];
      const vs = setKbVariant !== "" ? setKbVariant.split(",") : [];

      if (ls.length > 1)
        R.push({ k: "kb:next", t: "Alternar layout", d: "Próximo da lista", kind: "action" });

      for (let i = 0; i < ls.length; i++) {
        R.push({
          k: "kb:" + i, t: "Usar " + ls[i] + (vs[i] ? " (" + vs[i] + ")" : ""),
          d: "Layout " + (i + 1) + " de " + ls.length, kind: "action"
        });
      }
    } else if (p === "celularbg") {
      for (let i = 0; i < setWalls.length; i++)
        R.push({ k: "bg:" + i, t: phone.walls.baseName(setWalls[i]), d: "", kind: "radio", on: setWalls[i] === phone.celularBg });

      if (setWalls.length === 0)
        R.push({ k: "info", t: "Nenhuma imagem encontrada", d: "Coloque imagens em " + setBgDir, kind: "info" });
    } else if (p === "locales") {
      for (let i = 0; i < setLocales.length; i++)
        R.push({ k: "loc:" + i, t: setLocales[i], d: "", kind: "radio", on: setLocales[i] === setLocale });

      if (setLocales.length === 0)
        R.push({ k: "info", t: "Nenhum idioma encontrado", d: "Gere locales em /etc/locale.gen", kind: "info" });
    } else if (p === "about") {
      const a = setAbout;
      const add = (t, d) => {
        if (d && d !== "")
          R.push({ k: "info", t: t, d: d, kind: "info" });
      };

      add("Sistema", a.os);
      add("Modelo", a.model);
      add("Kernel", a.kernel);
      add("Uptime", a.uptime);
      add("Pacotes", a.pkgs && a.pkgs !== "0" ? a.pkgs + " (pacman)" : "");
      add("Shell", a.shell);
      add("WM", a.wm);
      add("CPU", a.cpu);
      add("GPU", a.gpu);
      add("Memória", a.mem);
      add("Disco", a.disk);
      add("Bateria", phone.sys.batPct >= 0 ? setBatSummary : "");
    }

    return R;
  }

  readonly property var setCurRow:
    (setSel >= 0 && setSel < setRows.length) ? setRows[setSel] : null

  // monitores desenhados na prévia da seção Telas
  readonly property var setMonRects: {
    const list = setMons.filter(m => !m.disabled && (!m.mirrorOf || m.mirrorOf === "none"));

    if (list.length === 0)
      return [];

    let minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;

    const lw = m => m.width / (m.scale || 1);
    const lh = m => m.height / (m.scale || 1);

    for (const m of list) {
      minX = Math.min(minX, m.x);
      minY = Math.min(minY, m.y);
      maxX = Math.max(maxX, m.x + lw(m));
      maxY = Math.max(maxY, m.y + lh(m));
    }

    const bw = phone.s(248);
    const bh = phone.s(70);
    const k = Math.min(bw / (maxX - minX), bh / (maxY - minY));
    const ox = (bw - (maxX - minX) * k) / 2;
    const oy = (bh - (maxY - minY) * k) / 2;

    return list.map(m => {
      const mirrors = setMons
        .filter(o => o.mirrorOf && o.mirrorOf !== "none" && (String(o.mirrorOf) === m.name || String(o.mirrorOf) === String(m.id)))
        .map(o => o.name);

      return {
        x: ox + (m.x - minX) * k,
        y: oy + (m.y - minY) * k,
        w: lw(m) * k,
        h: lh(m) * k,
        name: m.name,
        res: m.width + "x" + m.height,
        focused: !!m.focused,
        mir: mirrors.join(", ")
      };
    });
  }

  readonly property var setPageOpts: {
    const r = setCurRow;
    const o = [];

    if (setPage === "wifi") {
      o.push({ k: "refresh", t: "Atualizar redes" });

      if (r && r.k.indexOf("net:") === 0 && setNets[parseInt(r.k.slice(4))] && setNets[parseInt(r.k.slice(4))].saved)
        o.push({ k: "forget", t: "Esquecer rede" });
    } else if (setPage === "bluetooth") {
      o.push({ k: "scan", t: "Buscar dispositivos" });

      if (r && r.k.indexOf("dev:") === 0) {
        const bd = setBtDevs[parseInt(r.k.slice(4))];

        if (bd && bd.connected && bd.opp)
          o.push({ k: "send", t: "Enviar arquivo" });

        o.push({ k: "forget", t: "Esquecer dispositivo" });
      }
    } else if (setPage === "about") {
      o.push({ k: "photo", t: "Trocar foto" });
      o.push({ k: "refresh", t: "Atualizar" });
    } else if (setPage === "battery" || setPage === "screens" || setPage === "location" || setPage === "lang") {
      o.push({ k: "refresh", t: "Atualizar" });
    }

    return o;
  }

  readonly property string setSoftLeft:
    (setCardOn || setForm) ? "" : (setPageOpts.length > 0 ? "Opções" : "")

  readonly property string setSoftCenter: {
    if (setCardOn)
      return "OK";

    if (setForm)
      return "OK";

    if (setPage === "about")
      return "Trocar foto";

    const r = setCurRow;

    if (!r)
      return "";

    switch (r.kind) {
    case "toggle": return "Alternar";
    case "nav":    return "Abrir";
    case "radio":  return "Escolher";
    case "net":
    case "dev":    return r.on ? "Desconectar" : "Conectar";
    case "action": return "Executar";
    }

    return "";
  }

  readonly property string setSoftRight: setCardOn ? "Fechar" : (setForm ? "Cancelar" : "Voltar")

  readonly property string softLeftText: setSoftLeft
  readonly property string softCenterText: setSoftCenter
  readonly property string softRightText: setSoftRight

  function handleKey(e) { handleSettingsKey(e); }
  function softLeft() { setLeftKey(); }
  function softCenter() { setCenterKey(); }
  function softRight() { setBack(); }

  // ---------------- navegação ----------------

  function setEnter() {
    setOptOpen = false;
    setForm = false;

    if (setKeep) {
      setKeep = false;
    } else {
      setPage = "home";
      setSel = 0;
      setStatus = "";
    }

    phone.share.refreshShare();
    setRefresh(true);
  }

  function setGo(page) {
    setPage = page;
    setSel = 0;
    setStatus = "";
    setOptOpen = false;
    setRefresh(true);
  }

  function setBack() {
    if (setCardOn) {
      setCardClose();
      return;
    }

    if (setForm) {
      setForm = false;
      return;
    }

    if (setOptOpen) {
      setOptOpen = false;
      return;
    }

    if (setPage === "locales") {
      setGo("lang");
      setSel = 0;
      return;
    }

    if (setPage === "celularbg") {
      setGo("theme");
      setSel = 2;
      return;
    }

    if (setPage !== "home") {
      const i = setOrder.indexOf(setPage);

      setPage = "home";
      setStatus = "";
      setSel = Math.max(0, i);
      return;
    }

    phone.view = "menu";
  }

  function setMove(d) {
    const n = setRows.length;

    if (n === 0)
      return;

    setSel = Math.max(0, Math.min(n - 1, setSel + d));
  }

  // ---------------- leitura do estado ----------------

  readonly property string setScBat: `
    for d in /sys/class/power_supply/BAT*; do
      [ -r "$d/capacity" ] || continue
      echo "pct=$(cat "$d/capacity")"
      break
    done
    if command -v upower >/dev/null 2>&1; then
      b=$(upower -e 2>/dev/null | grep -m1 -i 'BAT')
      [ -n "$b" ] && upower -i "$b" 2>/dev/null | sed -n 's/^ *\\(time to empty\\|time to full\\|energy-rate\\|capacity\\): *\\(.*\\)$/up|\\1|\\2/p'
    fi
    if command -v powerprofilesctl >/dev/null 2>&1; then
      echo "prof=$(powerprofilesctl get 2>/dev/null)"
      powerprofilesctl list 2>/dev/null | sed -n 's/^[ *]*\\([a-z-]*\\):$/profs|\\1/p'
    fi

  `

  readonly property string setScMon: `hyprctl monitors all -j 2>/dev/null | tr -d '\\n'`

  readonly property string setScLoc: `
    echo "tz=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null)"
    echo "ntp=$(timedatectl show -p NTP --value 2>/dev/null)"
    echo "sync=$(timedatectl show -p NTPSynchronized --value 2>/dev/null)"
    echo "clock=$(date '+%d/%m/%Y %H:%M')"

  `

  readonly property string setScLang: `
    st=$(localectl status 2>/dev/null)
    echo "locale=$(printf '%s\\n' "$st" | sed -n 's/^ *System Locale: LANG=//p' | head -1)"
    echo "vc=$(printf '%s\\n' "$st" | sed -n 's/^ *VC Keymap: //p' | head -1)"
    if command -v hyprctl >/dev/null 2>&1; then
      echo "kbjson=$(hyprctl devices -j 2>/dev/null | tr -d '\\n')"
      echo "optl=$(hyprctl getoption input:kb_layout -j 2>/dev/null | tr -d '\\n')"
      echo "optv=$(hyprctl getoption input:kb_variant -j 2>/dev/null | tr -d '\\n')"
    fi

  `

  readonly property string setScWalls: `
    find "$1" -maxdepth 1 -type f 2>/dev/null \\
      | grep -iE '[.](png|jpe?g|webp|bmp|gif)$' \\
      | sort -f
  `

  readonly property string setScLocales: `localectl list-locales 2>/dev/null | grep -i 'utf-\\?8'`

  readonly property string setScAbout: `
    . /etc/os-release 2>/dev/null
    echo "host=$(cat /etc/hostname 2>/dev/null || uname -n)"
    echo "os=$PRETTY_NAME"
    echo "model=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)"
    echo "kernel=$(uname -r)"
    echo "uptime=$(uptime -p 2>/dev/null | sed 's/^up //')"
    echo "pkgs=$(pacman -Qq 2>/dev/null | wc -l)"
    echo "shell=$(basename "$SHELL")"
    echo "wm=$(hyprctl version 2>/dev/null | head -1 | sed 's/ built from.*//')"
    echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/(R)//g; s/(TM)//g; s/ CPU//; s/@.*//; s/^ *//; s/ *$//')"
    echo "gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | sed -E 's/^[^ ]+ [^:]+: //' | head -2 | tr '\\n' '|' | sed 's/|$//; s/|/ + /g')"
    echo "mem=$(free -m 2>/dev/null | awk '/^Mem:/ {printf "%.1f / %.1f GiB", $3/1024, $2/1024}')"
    echo "disk=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"

  `

  function setRefresh(first) {
    if (setInfoProc.running)
      return;

    let sc = "";
    let args = [];

    switch (setPage) {
    case "wifi":      sc = wifi.scanScript; args = [first ? "1" : "0"]; break;
    case "bluetooth": sc = bluetooth.scanScript; break;
    case "battery":   sc = setScBat; break;
    case "screens":   sc = setScMon; break;
    case "location":  sc = setScLoc; break;
    case "lang":      sc = setScLang; break;
    case "locales":   sc = setScLocales; break;
    case "celularbg": sc = setScWalls; args = [setBgDir]; break;
    case "about":     sc = setScAbout; break;
    default:          return;
    }

    setInfoPage = setPage;
    setInfoProc.command = ["sh", "-c", sc, "sh"].concat(args);
    setInfoProc.running = true;
  }

  function setKv(text) {
    const o = {};

    for (const l of text.split("\n")) {
      const k = l.indexOf("=");

      if (k > 0)
        o[l.slice(0, k)] = l.slice(k + 1).trim();
    }

    return o;
  }

  // só troca a propriedade se o conteúdo mudou (evita resetar a lista a cada leitura)
  function setPut(name, v) {
    if (JSON.stringify(self[name]) !== JSON.stringify(v))
      self[name] = v;
  }

  onSetRowsChanged: {
    if (setSel >= setRows.length)
      setSel = Math.max(0, setRows.length - 1);

    if (phone.view === "settings")
      Qt.callLater(function () { setListRef?.positionViewAtIndex(phone.config.setSel, ListView.Contain); });
  }

  function setParse(page, text) {
    if (page === "wifi") {
      const result = wifi.parseScan(text);
      wifi.networkManagerMissing = result.networkManagerMissing;
      wifi.radioOn = result.radioOn;
      setHotspotOn = result.hotspotOn;
      setPut("setAp", result.accessPoint);
      setPut("setNets", result.networks);
    } else if (page === "bluetooth") {
      const result = bluetooth.parseScan(text);
      bluetooth.power = result.powered;
      setPut("setBtDevs", result.devices);
    } else if (page === "battery") {
      const kv = setKv(text);
      const up = {};
      const profs = [];

      for (const l of text.split("\n")) {
        if (l.indexOf("up|") === 0) {
          const f = l.split("|");

          up[f[1]] = f.slice(2).join("|").trim();
        } else if (l.indexOf("profs|") === 0) {
          profs.push(l.slice(6).trim());
        }
      }

      setPut("setBatUp", up);
      setProfile = kv.prof || "";
      setPut("setProfiles", profs);
    } else if (page === "screens") {
      try {
        setPut("setMons", JSON.parse(text));
      } catch (e) {
        setPut("setMons", []);
      }
    } else if (page === "location") {
      const kv = setKv(text);

      setTz = kv.tz || "";
      setNtp = kv.ntp || "";
      setNtpSync = kv.sync || "";
      setClock = kv.clock || "";
    } else if (page === "lang") {
      const kv = setKv(text);

      setLocale = kv.locale || setLocale;
      setVc = kv.vc || "";

      try {
        const dv = JSON.parse(kv.kbjson || "{}");
        const kbs = dv.keyboards || [];
        const main = kbs.find(k => k.main) || kbs[0];

        setKbActive = main ? (main.active_keymap || "") : "";
      } catch (e) {
        setKbActive = "";
      }

      const str = j => {
        try {
          return JSON.parse(j || "{}").str || "";
        } catch (e) {
          return "";
        }
      };

      setKbLayout = str(kv.optl);
      setKbVariant = str(kv.optv);
    } else if (page === "celularbg") {
      setPut("setWalls", text.split("\n").map(l => l.trim()).filter(l => l !== ""));

      const cur = setWalls.indexOf(phone.celularBg);

      if (cur >= 0)
        setSel = cur;
    } else if (page === "locales") {
      setPut("setLocales", text.split("\n").map(l => l.trim()).filter(l => l !== ""));
    } else if (page === "about") {
      setPut("setAbout", setKv(text));
    }
  }

  Process {
    id: setInfoProc

    stdout: StdioCollector {
      onStreamFinished: phone.config.setParse(phone.config.setInfoPage, this.text)
    }
  }

  // enquanto a seção muda de estado sozinha (rede, bluetooth, bateria, telas)
  Timer {
    interval: 3500
    repeat: true
    running:
      phone.panelOpen && phone.view === "settings"
      && (phone.config.setPage === "wifi" || phone.config.setPage === "bluetooth"
          || phone.config.setPage === "battery" || phone.config.setPage === "screens")

    onTriggered: phone.config.setRefresh(false)
  }

  // ---------------- ações ----------------

  // roda um script do sistema e mostra o resultado; $1.. = args, QS_PW = segredo
  function setRun(label, script, args, env, okMsg) {
    if (setBusy)
      return;

    setBusy = true;
    setStatus = label;
    setActOk = okMsg || "Pronto";

    phone.shellRunner.run(label, script, args, env, okMsg, function (rc, lines) {
      phone.config.setBusy = false;

      if (rc === 0) {
        phone.config.setStatus = phone.config.setActOk;
      } else {
        phone.config.setStatus = "Falhou: " + (lines[lines.length - 1] || "código " + rc);

        if (lines.length > 1 || (lines[0] || "").length > 36)
          phone.config.setShowCard("Não deu certo", phone.config.setErrText(lines));
      }

      phone.config.setActFinished(rc === 0);
    });
  }

  Timer {
    id: setStatusClear

    interval: 5000

    onTriggered: phone.config.setStatus = ""
  }

  // texto do cartão de erro: as últimas linhas da saída + uma dica, se reconhecer o problema
  function setErrText(msg) {
    const t = msg.slice(-5).join("\n");
    let hint = "";

    if (/channel|frequency|DFS|no-IR|freq/i.test(t))
      hint = "\n\nDica: conecte o notebook numa rede de 2,4 GHz (sem “_5G”) e tente de novo. Canais de 5 GHz muitas vezes não aceitam ponto de acesso.";
    else if (/not authorized|authority|polkit|dismissed|pkexec/i.test(t))
      hint = "\n\nDica: é preciso um agente polkit rodando para pedir a senha de administrador.";
    else if (/(hostapd|dnsmasq|iptables|nft).*(not found|No such file)|(not found|No such file).*(hostapd|dnsmasq|iptables|nft)/i.test(t))
      hint = "\n\nDica: instale hostapd, dnsmasq e iptables (dependências do create_ap).";

    return t + hint;
  }

  function setActFinished(ok) {
    setStatusClear.restart();
    setRefreshSoon.restart();
  }

  Timer {
    id: setRefreshSoon

    interval: 900

    onTriggered: phone.config.setRefresh(false)
  }

  function setActivate() {
    const r = setCurRow;

    if (!r || setBusy && r.kind !== "nav")
      return;

    const k = r.k;

    if (k.indexOf("go:") === 0) {
      setGo(k.slice(3));
      return;
    }

    if (k.indexOf("bg:") === 0) {
      const img = setWalls[parseInt(k.slice(3))];

      if (img) {
        phone.celularBg = img;
        setSave();
      }

      return;
    }

    switch (k) {
    // ---- wifi ----
    case "wifi:toggle":
      wifi.toggleRadio();
      return;

    case "hotspot:toggle":
      setHotspotToggle();
      return;

    case "hotspot:cfg":
      setOpenHotspotForm(false);
      return;

    case "hotspot:qr":
      setShowQr();
      return;

    // ---- bluetooth ----
    case "bt:recv":
      setBtRecvToggle();
      return;

    case "bt:toggle":
      bluetooth.togglePower();
      return;

    case "bt:scan":
      setBtStartScan();
      return;

    // ---- tema ----
    case "theme:dark":
    case "theme:light":
      phone.themeDark = k === "theme:dark";
      setSave();
      return;

    // ---- telas ----
    case "share":
      phone.view = "share";
      return;

    // ---- local ----
    case "ntp:toggle":
      setRun("Hora automática…", "timedatectl set-ntp " + (setNtp === "yes" ? "false" : "true"), [], null,
             setNtp === "yes" ? "Hora automática desligada" : "Hora automática ligada");
      return;

    case "loc:detect":
      setDetectLocation();
      return;

    case "loc:tz":
      setRun("Trocando fuso…", 'timedatectl set-timezone "$1"', [setIp.timezone], null,
             "Fuso: " + setIp.timezone);
      return;

    // ---- teclado ----
    case "kb:next":
      setRun("Layout…", "hyprctl switchxkblayout all next", [], null, "Layout alternado");
      return;
    }

    if (k.indexOf("net:") === 0) {
      setNetActivate(parseInt(k.slice(4)));
    } else if (k.indexOf("dev:") === 0) {
      setDevActivate(parseInt(k.slice(4)));
    } else if (k.indexOf("prof:") === 0) {
      const pr = k.slice(5);

      setRun("Modo de energia…", 'powerprofilesctl set "$1"', [pr], null, "Modo aplicado");
    } else if (k.indexOf("kb:") === 0) {
      setRun("Layout…", 'hyprctl switchxkblayout all "$1"', [k.slice(3)], null, "Layout aplicado");
    } else if (k.indexOf("loc:") === 0) {
      const loc = setLocales[parseInt(k.slice(4))];

      if (loc)
        setRun("Trocando idioma…", 'localectl set-locale LANG="$1"', [loc], null,
               "Idioma: " + loc + " (vale na próxima sessão)");
    }
  }

  // ---- wifi ----

  function setNetActivate(i) { wifi.connectNetwork(i); }

  // ---- compartilhar a internet do notebook com o celular ----
  //
  // De onde vem a internet (rota padrão) decide como compartilhar:
  //   wired      cabo: o ponto de acesso usa a placa Wi-Fi (nmcli)
  //   second     Wi-Fi + uma 2ª placa (ex.: adaptador USB): a 2ª vira o ponto de acesso
  //   concurrent Wi-Fi com a mesma placa: precisa de suporte AP+STA do driver e do
  //              create_ap (linux-wifi-hotspot), que sobe uma interface virtual
  //   nosupport  Wi-Fi com uma placa que não divide: não dá
  readonly property var setHotspotPlan: hotspot.plan

  property bool setCardOn: false

  property string setCardTitle: ""

  property string setCardBody: ""

  property string setCardImage: ""

  property int setCardRev: 0

  readonly property string setQrPath:
    (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-phone-hotspot-qr.png"

  function setShowCard(title, body) {
    setCardTitle = title;
    setCardBody = body;
    setCardImage = "";
    setCardOn = true;
  }

  function setCardClose() {
    setCardOn = false;

    // o QR tem a senha: não deixa o arquivo por aí
    if (setCardImage !== "")
      Quickshell.execDetached(["rm", "-f", setQrPath]);

    setCardImage = "";
  }

  function setShowQr() { hotspot.showQr(); }
  function setHotspotToggle() { hotspot.toggle(); }
  function setStartHotspot(planId) { hotspot.start(planId); }

  function setOpenHotspotForm(thenStart) {
    setFormTitle = "Rede compartilhada";
    setFormHint = "É o nome e a senha (8+ caracteres) que o celular vai usar para conectar.";
    setFormAction = "hotspot";
    setFormCtx = thenStart ? "start" : "";
    setFormFields = [
      { label: "Nome", value: hotspotSsid !== "" ? hotspotSsid : Quickshell.env("USER") + "-notebook", mask: false },
      { label: "Senha", value: hotspotPass, mask: false }
    ];
    setFormFocus = 0;
    setForm = true;
  }

  // ---- bluetooth ----

  function setBtStartScan() {
    bluetooth.startScan();
  }

  function setDevActivate(i) {
    bluetooth.activateDevice(i);
  }

  // Operacoes de arquivo delegadas ao modulo Bluetooth.
  function setBtSendPick(device) { bluetooth.pickFile(device); }
  function setBtSend(path) { bluetooth.sendFile(path); }
  function setBtRecvToggle() { bluetooth.toggleReceiving(); }
  function setBtRecvStop() { bluetooth.stopReceiving(); }

  // ---- local ----

  function setDetectLocation() {
    if (setIpBusy)
      return;

    setIpBusy = true;
    setIp = ({});
    setIpProc.running = true;
  }

  Process {
    id: setIpProc

    command: ["curl", "-s", "--max-time", "7", "https://ipinfo.io/json"]

    stdout: StdioCollector {
      onStreamFinished: {
        phone.config.setIpBusy = false;

        try {
          const j = JSON.parse(this.text);

          phone.config.setIp = j.city
            ? j
            : ({ error: "Resposta sem cidade" });
        } catch (e) {
          phone.config.setIp = ({ error: "Sem internet ou serviço fora do ar" });
        }
      }
    }
  }

  // ---- formulário ----

  function setFormSubmit() {
    const f = setFormFields;

    if (setFormAction === "wifipw") {
      if (f[0].value === "")
        return;

      const ssid = setFormCtx;

      setForm = false;
      setRun("Conectando…", 'nmcli device wifi connect "$1" password "$QS_PW"', [ssid],
             ({ "QS_PW": f[0].value }), "Conectado a " + ssid);
    } else if (setFormAction === "hotspot") {
      const name = f[0].value.trim();
      const pass = f[1].value;

      if (name === "" || pass.length < 8) {
        setStatus = "Nome e senha (8+ caracteres) são obrigatórios";
        setStatusClear.restart();
        return;
      }

      hotspotSsid = name;
      hotspotPass = pass;
      setSave();
      setForm = false;

      if (setFormCtx === "start")
        setStartHotspot(setHotspotPlan.id);
      else
        setStatus = "Rede compartilhada salva";
    }
  }

  function setFormSet(i, v) {
    const a = setFormFields.slice();

    a[i] = { label: a[i].label, value: v, mask: a[i].mask };
    setFormFields = a;
  }

  function handleSetFormKey(e) {
    const n = setFormFields.length;
    const i = setFormFocus;
    let ok = true;

    if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_V) {
      if (!setPasteProc.running)
        setPasteProc.running = true;
    } else {
      switch (e.key) {
      case Qt.Key_Escape:
        setForm = false;
        break;

      case Qt.Key_Tab:
      case Qt.Key_Down:
        setFormFocus = (i + 1) % n;
        break;

      case Qt.Key_Backtab:
      case Qt.Key_Up:
        setFormFocus = (i + n - 1) % n;
        break;

      case Qt.Key_Return:
      case Qt.Key_Enter:
        if (i < n - 1)
          setFormFocus = i + 1;
        else
          setFormSubmit();
        break;

      case Qt.Key_Backspace:
        setFormSet(i, setFormFields[i].value.slice(0, -1));
        break;

      default:
        if (e.text && e.text.length === 1 && e.text >= " ")
          setFormSet(i, setFormFields[i].value + e.text);
        else
          ok = false;
      }
    }

    if (ok)
      e.accepted = true;
  }

  Process {
    id: setPasteProc

    command: ["wl-paste", "-n", "-t", "text"]

    stdout: StdioCollector {
      onStreamFinished: {
        const t = this.text.replace(/[\x00-\x1f]/g, "");

        if (t !== "" && phone.config.setForm)
          phone.config.setFormSet(phone.config.setFormFocus, phone.config.setFormFields[phone.config.setFormFocus].value + t);
      }
    }
  }

  // ---------------- opções (popup) ----------------

  function setOptRun(k) {
    setOptOpen = false;

    const r = setCurRow;

    switch (k) {
    case "refresh":
      setRefresh(true);
      break;

    case "scan":
      setBtStartScan();
      break;

    case "photo":
      setPickPhoto();
      break;

    case "send":
      if (r && r.k.indexOf("dev:") === 0)
        setBtSendPick(setBtDevs[parseInt(r.k.slice(4))]);

      break;

    case "forget":
      if (r && r.k.indexOf("net:") === 0) {
        const n = setNets[parseInt(r.k.slice(4))];

        wifi.forgetNetwork(n);
      } else if (r && r.k.indexOf("dev:") === 0) {
        const d = setBtDevs[parseInt(r.k.slice(4))];

        setRun("Esquecendo dispositivo…", 'bluetoothctl remove "$1"', [d.mac], null, "Dispositivo esquecido");
      }
      break;
    }
  }

  function handleSetOptKey(e) {
    const n = setPageOpts.length;

    if (n === 0) {
      setOptOpen = false;
      return;
    }

    switch (e.key) {
    case Qt.Key_Up:    setOptSel = (setOptSel + n - 1) % n; break;
    case Qt.Key_Down:  setOptSel = (setOptSel + 1) % n;     break;

    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Right:
      setOptRun(setPageOpts[Math.min(setOptSel, n - 1)].k);
      break;

    case Qt.Key_Escape:
    case Qt.Key_Left:
      setOptOpen = false;
      break;

    default:
      return;
    }

    e.accepted = true;
  }

  // troca a foto do usuário (usa o mesmo fluxo da tela Sistema)
  function setPickPhoto() {
    phone.files.openFiles(true);
    phone.files.filesReturnView = "settings";
    avatarReturn = "settings";
    setKeep = true;
  }

  // ---------------- teclado e softkeys ----------------

  function handleSettingsKey(e) {
    if (setCardOn) {
      setCardClose();
      e.accepted = true;
      return;
    }

    if (setForm) {
      handleSetFormKey(e);
      return;
    }

    if (setOptOpen) {
      handleSetOptKey(e);
      return;
    }

    let ok = true;

    switch (e.key) {
    case Qt.Key_Escape:
    case Qt.Key_Backspace:
    case Qt.Key_Left:
      setBack();
      break;

    case Qt.Key_Up:       setMove(-1); break;
    case Qt.Key_Down:     setMove(1);  break;
    case Qt.Key_PageUp:   setMove(-5); break;
    case Qt.Key_PageDown: setMove(5);  break;

    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Right:
    case Qt.Key_Space:
      if (setPage === "about")
        setPickPhoto();
      else
        setActivate();
      break;

    case Qt.Key_F5:
      setRefresh(true);
      break;

    default:
      ok = false;
    }

    if (ok)
      e.accepted = true;
  }

  function setLeftKey() {
    if (setCardOn || setForm || setPageOpts.length === 0)
      return;

    setOptOpen = !setOptOpen;
  }

  function setCenterKey() {
    if (setCardOn) {
      setCardClose();
      return;
    }

    if (setForm) {
      setFormSubmit();
      return;
    }

    if (setOptOpen) {
      setOptRun(setPageOpts[Math.min(setOptSel, setPageOpts.length - 1)].k);
      return;
    }

    if (setPage === "about")
      setPickPhoto();
    else
      setActivate();
  }

  onSetOptOpenChanged: {
    if (setOptOpen)
      setOptSel = 0;
  }

  onSetSelChanged: {
    if (phone.view === "settings")
      setListRef?.positionViewAtIndex(setSel, ListView.Contain);
  }
}
