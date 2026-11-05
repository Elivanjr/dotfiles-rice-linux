// logic/CommandScheduler.qml — Agendar comandos com o `at`
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "sched".
// Acesso de fora:  phone.sched.<membro>
// Tela: views/ScheduleView.qml | Script: scripts/at/at-schedule.sh
//
// Fluxo:  list  (jobs do atq)
//           └─ Novo ─> cmd (o que executar) -> date (calendário) -> time (hora)
// O atd já precisa estar rodando; aqui só se usa at / atq / atrm.
// O dia e a hora escolhidos viram um carimbo AAAAMMDDhhmm (`at -t`).

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  property alias schedModel: schedModelObj

  property string schedStage: "list"        // list | cmd | date | time

  // ---- lista ----
  property int schedSel: 0

  property bool schedConfirm: false         // remoção armada (pede confirmação)

  property string schedStatus: ""           // aviso na lista

  property string schedListError: ""        // falha do atq (atd parado etc.)

  property string schedRaw: ""              // texto bruto do último list

  // ---- novo agendamento ----
  property bool schedBusy: false

  property string schedMsg: ""              // erro/aviso nos passos do formulário

  property string schedCmd: ""

  property var schedPick: new Date()        // dia + hora escolhidos (sempre trocar o objeto)

  property var schedToday: new Date()       // hoje à meia-noite (limite do calendário)

  property int schedTimeField: 0            // 0 = hora, 1 = minuto

  property string schedDigits: ""           // 1º dígito digitado, esperando o 2º

  property int schedPresetIdx: -1

  readonly property var schedPresets: [
    { t: "1 min",     kind: "min", v: 1 },
    { t: "5 min",     kind: "min", v: 5 },
    { t: "30 min",    kind: "min", v: 30 },
    { t: "1 h",       kind: "min", v: 60 },
    { t: "Amanhã 9h", kind: "tom", v: 0 }
  ]

  readonly property var schedMonths: [
    "janeiro", "fevereiro", "março", "abril", "maio", "junho",
    "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"
  ]

  readonly property var schedWeekdays: ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]

  readonly property string schedScript:
    decodeURIComponent(String(Qt.resolvedUrl("../scripts/at/at-schedule.sh")).replace("file://", ""))

  ListModel {
    id: schedModelObj
  }

  // ---------------- textos ----------------

  function pad2(n) {
    return (n < 10 ? "0" : "") + n;
  }

  readonly property string schedMonthLabel:
    schedMonths[schedPick.getMonth()] + " de " + schedPick.getFullYear()

  readonly property string schedDateLabel:
    schedWeekdays[schedPick.getDay()] + ", " + pad2(schedPick.getDate()) + "/"
      + pad2(schedPick.getMonth() + 1) + "/" + schedPick.getFullYear()

  readonly property string schedHourText: pad2(schedPick.getHours())

  readonly property string schedMinuteText: pad2(schedPick.getMinutes())

  readonly property string schedTitle: {
    switch (schedStage) {
    case "cmd":  return "Novo";
    case "date": return "Dia";
    case "time": return "Hora";
    default:     return "Agendar";
    }
  }

  readonly property string schedSubtitle: {
    switch (schedStage) {
    case "cmd":  return "1 de 3 · O que executar";
    case "date": return "2 de 3 · " + schedMonthLabel;
    case "time": return "3 de 3 · " + schedDateLabel;
    default:
      return schedModel.count === 0
        ? "Nenhum comando agendado"
        : schedModel.count + (schedModel.count === 1 ? " comando agendado" : " comandos agendados");
    }
  }

  readonly property string schedSoftLeft: {
    switch (schedStage) {
    case "cmd":  return "Limpar";
    case "date": return "Hoje";
    case "time": return "Rápido";
    default:     return "Novo";
    }
  }

  readonly property string schedSoftCenter: {
    switch (schedStage) {
    case "cmd":  return schedCmd.trim() === "" ? "" : "Próximo";
    case "date": return "Próximo";
    case "time": return "Agendar";
    default:     return schedModel.count === 0 ? "" : (schedConfirm ? "Confirmar" : "Remover");
    }
  }

  readonly property string schedSoftRight:
    schedStage === "cmd" ? "Cancelar" : "Voltar"

  // "hoje 14:05 · em 5 min"  (usa o relógio do player, que já anda 1x/s)
  function whenText(epoch) {
    const now = phone.music.now;
    const d = new Date(epoch * 1000);

    if (!epoch || isNaN(d.getTime()))
      return "horário desconhecido";

    const hm = pad2(d.getHours()) + ":" + pad2(d.getMinutes());
    const day0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const diffDays = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime() - day0) / 86400000);

    let day;

    if (diffDays === 0)
      day = "hoje";
    else if (diffDays === 1)
      day = "amanhã";
    else
      day = pad2(d.getDate()) + "/" + pad2(d.getMonth() + 1)
        + (d.getFullYear() !== now.getFullYear() ? "/" + d.getFullYear() : "");

    const secs = Math.round((d.getTime() - now.getTime()) / 1000);
    let rel = "";

    if (secs <= 0)
      rel = "agora";
    else if (secs < 3600)
      rel = "em " + Math.max(1, Math.round(secs / 60)) + " min";
    else if (secs < 86400)
      rel = "em " + Math.floor(secs / 3600) + " h " + pad2(Math.floor((secs % 3600) / 60)) + " min";

    return day + " " + hm + (rel !== "" ? " · " + rel : "");
  }

  // ---------------- lista ----------------

  function schedEnter() {
    schedStage = "list";
    schedConfirm = false;
    schedMsg = "";
    schedRefresh();
  }

  function schedRefresh() {
    if (schedListProc.running)
      return;

    schedListProc.command = ["sh", schedScript, "list"];
    schedListProc.running = true;
  }

  // separa o código de retorno (última linha __QS_RC__=N) do resto da saída
  function schedSplitRc(raw) {
    const m = raw.match(/__QS_RC__=(\d+)\s*$/);

    return {
      code: m ? parseInt(m[1]) : 1,
      text: m ? raw.slice(0, m.index) : raw
    };
  }

  function schedParse(raw) {
    const r = schedSplitRc(raw);
    const text = r.text;

    if (r.code !== 0) {
      schedListError = text.trim() !== "" ? text.trim().split("\n")[0] : "Não consegui consultar o atq.";
      schedRaw = "";
      schedModel.clear();
      return;
    }

    schedListError = "";

    if (text === schedRaw)
      return;

    schedRaw = text;

    // mantém a seleção no mesmo job quando a lista muda
    const keepId = (schedSel >= 0 && schedSel < schedModel.count) ? schedModel.get(schedSel).jobId : "";
    const rows = [];
    const lines = text.split("\n");

    for (let i = 0; i < lines.length; i++) {
      const p = lines[i].split("\t");

      if (p.length < 3 || !/^\d+$/.test(p[0]))
        continue;

      rows.push({
        jobId: p[0],
        epoch: parseInt(p[1]) || 0,
        running: p[2] === "=",
        cmd: (p.slice(3).join(" ") || "(comando não identificado)")
      });
    }

    rows.sort(function (a, b) { return a.epoch - b.epoch; });

    schedModel.clear();

    for (const r2 of rows)
      schedModel.append(r2);

    let idx = 0;

    for (let i = 0; i < schedModel.count; i++) {
      if (schedModel.get(i).jobId === keepId)
        idx = i;
    }

    schedSel = Math.max(0, Math.min(idx, schedModel.count - 1));

    if (schedModel.count === 0)
      schedConfirm = false;
  }

  function schedMove(d) {
    const n = schedModel.count;

    schedConfirm = false;

    if (n === 0)
      return;

    schedSel = Math.max(0, Math.min(n - 1, schedSel + d));
  }

  // Remover: 1º toque arma, 2º confirma
  function schedRemoveKey() {
    if (schedModel.count === 0 || schedSel < 0 || schedSel >= schedModel.count)
      return;

    if (!schedConfirm) {
      schedConfirm = true;
      schedStatus = "Remover #" + schedModel.get(schedSel).jobId + "? Toque de novo para confirmar.";
      return;
    }

    schedConfirm = false;

    if (schedRmProc.running)
      return;

    const id = schedModel.get(schedSel).jobId;

    schedStatus = "Removendo #" + id + "…";
    schedRmProc.command = ["sh", schedScript, "rm", id];
    schedRmProc.running = true;
  }

  function schedOnRmDone(raw) {
    const r = schedSplitRc(raw);

    schedStatus = r.code === 0 ? "Job removido." : ("Falha ao remover: " + r.text.trim());
    schedRefresh();
  }

  // ---------------- datas ----------------

  function dayStart(d) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate());
  }

  function daysIn(y, m) {
    return new Date(y, m + 1, 0).getDate();
  }

  function atTime(d, h, m) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), h, m);
  }

  // troca o dia/hora escolhidos; nunca antes de hoje
  function schedSetPick(d, keepPreset) {
    let n = d;

    if (dayStart(n).getTime() < schedToday.getTime())
      n = atTime(schedToday, n.getHours(), n.getMinutes());

    schedPick = n;
    schedMsg = "";

    if (!keepPreset)
      schedPresetIdx = -1;
  }

  function schedAddDays(n) {
    const p = schedPick;

    schedSetPick(new Date(p.getFullYear(), p.getMonth(), p.getDate() + n, p.getHours(), p.getMinutes()));
  }

  function schedAddMonths(n) {
    const p = schedPick;
    const first = new Date(p.getFullYear(), p.getMonth() + n, 1);
    const day = Math.min(p.getDate(), daysIn(first.getFullYear(), first.getMonth()));

    schedSetPick(new Date(first.getFullYear(), first.getMonth(), day, p.getHours(), p.getMinutes()));
  }

  function schedGoToday() {
    const n = new Date();
    const p = schedPick;

    schedSetPick(new Date(n.getFullYear(), n.getMonth(), n.getDate(), p.getHours(), p.getMinutes()));
  }

  // célula i (0..41) da grade do mês exibido; semana começa no domingo
  function schedCell(i) {
    const p = schedPick;
    const first = new Date(p.getFullYear(), p.getMonth(), 1);
    const d = new Date(p.getFullYear(), p.getMonth(), 1 - first.getDay() + i);
    const t = d.getTime();

    return {
      day: d.getDate(),
      inMonth: d.getMonth() === p.getMonth(),
      sel: d.getFullYear() === p.getFullYear() && d.getMonth() === p.getMonth() && d.getDate() === p.getDate(),
      today: t === schedToday.getTime(),
      past: t < schedToday.getTime(),
      time: t
    };
  }

  // clique numa célula: escolhe o dia; clicar no dia já escolhido avança
  function schedClickCell(i) {
    const c = schedCell(i);

    if (c.past)
      return;

    if (c.sel) {
      schedNextStep();
      return;
    }

    const d = new Date(c.time);

    schedSetPick(atTime(d, schedPick.getHours(), schedPick.getMinutes()));
  }

  // ---------------- hora ----------------

  function schedSetTime(h, m) {
    schedSetPick(atTime(schedPick, h, m));
    schedDigits = "";
  }

  function schedAdjustTime(delta) {
    const h = schedPick.getHours();
    const m = schedPick.getMinutes();

    if (schedTimeField === 0)
      schedSetTime(((h + delta) % 24 + 24) % 24, m);
    else
      schedSetTime(h, ((m + delta) % 60 + 60) % 60);
  }

  function schedTypeDigit(ch) {
    const d = parseInt(ch);
    let h = schedPick.getHours();
    let m = schedPick.getMinutes();

    if (schedTimeField === 0) {
      if (schedDigits === "") {
        h = d;

        if (d >= 3) {                         // 3..9 só pode ser a hora inteira
          schedTimeField = 1;
          schedDigits = "";
        } else {
          schedDigits = String(d);
        }
      } else {
        const v = parseInt(schedDigits) * 10 + d;

        h = v <= 23 ? v : d;
        schedDigits = "";
        schedTimeField = 1;
      }
    } else {
      if (schedDigits === "") {
        m = d;
        schedDigits = d >= 6 ? "" : String(d);
      } else {
        m = parseInt(schedDigits) * 10 + d;
        schedDigits = "";
      }
    }

    schedSetPick(atTime(schedPick, h, m));
  }

  function schedSetField(f) {
    schedTimeField = f;
    schedDigits = "";
  }

  // atalhos relativos a agora
  function schedApplyPreset(i) {
    if (i < 0 || i >= schedPresets.length)
      return;

    const p = schedPresets[i];
    const n = new Date();
    let d;

    if (p.kind === "tom")
      d = new Date(n.getFullYear(), n.getMonth(), n.getDate() + 1, 9, 0);
    else
      d = new Date(n.getFullYear(), n.getMonth(), n.getDate(), n.getHours(), n.getMinutes() + p.v);

    schedToday = dayStart(n);
    schedSetPick(d, true);
    schedPresetIdx = i;
    schedDigits = "";
  }

  function schedNextPreset() {
    schedApplyPreset((schedPresetIdx + 1) % schedPresets.length);
  }

  // ---------------- formulário (passos) ----------------

  function schedNew() {
    const n = new Date();

    schedCmd = "";
    schedMsg = "";
    schedConfirm = false;
    schedToday = dayStart(n);
    schedPick = new Date(n.getFullYear(), n.getMonth(), n.getDate(), n.getHours(), n.getMinutes() + 5);
    schedPresetIdx = -1;
    schedTimeField = 0;
    schedDigits = "";
    schedStage = "cmd";
  }

  function schedTypeCmd(str) {
    if (!str)
      return;

    schedCmd = (schedCmd + String(str).replace(/[\r\n]+/g, " ")).slice(0, 400);
    schedMsg = "";
  }

  function schedNextStep() {
    if (schedStage === "cmd") {
      if (schedCmd.trim() === "") {
        schedMsg = "Escreva o comando que será executado.";
        return;
      }

      schedMsg = "";
      schedToday = dayStart(new Date());
      schedStage = "date";
    } else if (schedStage === "date") {
      schedMsg = "";
      schedStage = "time";
    } else if (schedStage === "time") {
      schedSubmit();
    }
  }

  function schedPrevStep() {
    schedMsg = "";

    if (schedStage === "time")
      schedStage = "date";
    else if (schedStage === "date")
      schedStage = "cmd";
    else if (schedStage === "cmd")
      schedStage = "list";
  }

  function schedStamp(d) {
    return d.getFullYear() + pad2(d.getMonth() + 1) + pad2(d.getDate()) + pad2(d.getHours()) + pad2(d.getMinutes());
  }

  function schedSubmit() {
    const cmd = schedCmd.trim();

    if (schedAddProc.running)
      return;

    if (cmd === "") {
      schedMsg = "Escreva o comando que será executado.";
      schedStage = "cmd";
      return;
    }

    // o at trabalha em minutos: precisa ser pelo menos o próximo minuto
    const nextMinute = Math.floor(Date.now() / 60000) * 60000 + 60000;

    if (schedPick.getTime() < nextMinute) {
      schedMsg = "Esse horário já passou. Escolha daqui a pelo menos 1 minuto.";
      schedStage = "time";
      return;
    }

    schedBusy = true;
    schedMsg = "";
    schedAddProc.environment = ({ "QS_AT_CMD": cmd, "QS_AT_STAMP": schedStamp(schedPick) });
    schedAddProc.command = ["sh", schedScript, "add-t"];
    schedAddProc.running = true;
  }

  function schedOnAddDone(raw) {
    const r = schedSplitRc(raw);
    const txt = r.text.trim();
    const m = txt.match(/job (\d+) at/);

    schedBusy = false;

    if (r.code === 0 && m) {
      schedStage = "list";
      schedStatus = "Agendado #" + m[1] + " para " + schedDateLabel + " " + schedHourText + ":" + schedMinuteText + "."
        + (/daemon not running/i.test(txt) ? " Atenção: o atd não está rodando." : "");
      schedRefresh();
      return;
    }

    if (/invalid date/i.test(txt))
      schedMsg = "Essa data não existe no calendário.";
    else if (txt !== "")
      schedMsg = txt.split("\n").filter(function (l) { return !/^warning:/i.test(l); }).join(" ").slice(0, 160);
    else
      schedMsg = "Falha ao agendar (código " + r.code + ").";

    schedStage = "time";
  }

  // ---------------- teclado ----------------

  function handleSchedKey(e) {
    const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
    let ok = false;

    switch (schedStage) {
    case "cmd":  ok = schedCmdKey(e, ctrl);  break;
    case "date": ok = schedDateKey(e);       break;
    case "time": ok = schedTimeKey(e);       break;
    default:     ok = schedListKey(e);       break;
    }

    if (ok)
      e.accepted = true;
  }

  function schedListKey(e) {
    switch (e.key) {
    case Qt.Key_Escape:
      if (schedConfirm)
        schedConfirm = false;
      else
        phone.view = "menu";

      return true;

    case Qt.Key_Up:       schedMove(-1); return true;
    case Qt.Key_Down:     schedMove(1);  return true;
    case Qt.Key_PageUp:   schedMove(-5); return true;
    case Qt.Key_PageDown: schedMove(5);  return true;

    case Qt.Key_N:
    case Qt.Key_Insert:
      schedNew();
      return true;

    case Qt.Key_R:
    case Qt.Key_F5:
      schedStatus = "";
      schedRefresh();
      return true;

    case Qt.Key_Delete:
    case Qt.Key_Return:
    case Qt.Key_Enter:
      schedRemoveKey();
      return true;

    default:
      return false;
    }
  }

  function schedCmdKey(e, ctrl) {
    if (ctrl && e.key === Qt.Key_V) {
      if (!schedPasteProc.running)
        schedPasteProc.running = true;

      return true;
    }

    switch (e.key) {
    case Qt.Key_Escape:
      schedPrevStep();
      return true;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      schedNextStep();
      return true;

    case Qt.Key_Backspace:
      schedCmd = schedCmd.slice(0, -1);
      schedMsg = "";
      return true;

    default:
      if (e.text && e.text.length === 1 && e.text >= " ") {
        schedTypeCmd(e.text);
        return true;
      }

      return false;
    }
  }

  function schedDateKey(e) {
    switch (e.key) {
    case Qt.Key_Escape:   schedPrevStep();  return true;
    case Qt.Key_Return:
    case Qt.Key_Enter:    schedNextStep();  return true;

    case Qt.Key_Left:     schedAddDays(-1);   return true;
    case Qt.Key_Right:    schedAddDays(1);    return true;
    case Qt.Key_Up:       schedAddDays(-7);   return true;
    case Qt.Key_Down:     schedAddDays(7);    return true;
    case Qt.Key_PageUp:   schedAddMonths(-1); return true;
    case Qt.Key_PageDown: schedAddMonths(1);  return true;

    case Qt.Key_Home:
    case Qt.Key_T:
      schedGoToday();
      return true;

    default:
      return false;
    }
  }

  function schedTimeKey(e) {
    switch (e.key) {
    case Qt.Key_Escape:
      schedPrevStep();
      return true;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      schedNextStep();
      return true;

    case Qt.Key_Left:     schedSetField(0); return true;
    case Qt.Key_Right:    schedSetField(1); return true;

    case Qt.Key_Up:       schedAdjustTime(1);  return true;
    case Qt.Key_Down:     schedAdjustTime(-1); return true;

    case Qt.Key_PageUp:   schedAdjustTime(schedTimeField === 0 ? 6 : 10);  return true;
    case Qt.Key_PageDown: schedAdjustTime(schedTimeField === 0 ? -6 : -10); return true;

    case Qt.Key_Tab:
      schedNextPreset();
      return true;

    default:
      if (e.text && e.text.length === 1 && e.text >= "0" && e.text <= "9") {
        schedTypeDigit(e.text);
        return true;
      }

      return false;
    }
  }

  // ---------------- softkeys (chamadas pelo KeyControls) ----------------

  function schedLeftKey() {
    switch (schedStage) {
    case "cmd":
      schedCmd = "";
      schedMsg = "";
      break;

    case "date":
      schedGoToday();
      break;

    case "time":
      schedNextPreset();
      break;

    default:
      schedNew();
      break;
    }
  }

  function schedCenterKey() {
    if (schedStage === "list")
      schedRemoveKey();
    else
      schedNextStep();
  }

  function schedBack() {
    if (schedStage !== "list") {
      schedPrevStep();
      return;
    }

    if (schedConfirm) {
      schedConfirm = false;
      return;
    }

    phone.view = "menu";
  }

  // ---------------- processos ----------------

  Timer {
    interval: 10000
    repeat: true
    running: phone.panelOpen && phone.view === "sched" && phone.sched.schedStage === "list"

    onTriggered: phone.sched.schedRefresh()
  }

  Process {
    id: schedListProc

    stdout: StdioCollector {
      onStreamFinished: phone.sched.schedParse(this.text)
    }
  }

  Process {
    id: schedAddProc

    stdout: StdioCollector {
      onStreamFinished: phone.sched.schedOnAddDone(this.text)
    }
  }

  Process {
    id: schedRmProc

    stdout: StdioCollector {
      onStreamFinished: phone.sched.schedOnRmDone(this.text)
    }
  }

  // Ctrl+V: cola o clipboard no comando
  Process {
    id: schedPasteProc

    command: ["wl-paste", "-n", "-t", "text"]

    stdout: StdioCollector {
      onStreamFinished: phone.sched.schedTypeCmd(this.text)
    }
  }
}
