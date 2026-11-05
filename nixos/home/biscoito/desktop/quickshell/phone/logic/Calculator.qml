// logic/Calculator.qml — Calculadora
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "calc".
// Acesso de fora:  phone.calc.<membro>

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: self

  required property var phone

  // ================================================================
  // CALCULADORA
  //
  // Conta com + − × ÷, potência (^), porcentagem, parênteses e sinal.
  // Digite no teclado do PC ou use o D-pad (setas + OK) e o mouse.
  // O cálculo é feito por um analisador próprio (sem eval).
  // ================================================================

  property string calcExpr: ""          // interno: usa . * / - + ^ % ( )

  property string calcHist: ""          // "2+2 =" da última conta

  property bool calcDone: false

  property bool calcErr: false

  property string calcErrMsg: ""

  property int calcSel: 19              // tecla destacada (começa no "=")

  readonly property var calcKeys: [
    { t: "C",      k: "C",   kind: "fn" },
    { t: "\u2190", k: "BS",  kind: "fn" },
    { t: "%",      k: "%",   kind: "fn" },
    { t: "\u00F7", k: "/",   kind: "op" },
    { t: "7",      k: "7",   kind: "num" },
    { t: "8",      k: "8",   kind: "num" },
    { t: "9",      k: "9",   kind: "num" },
    { t: "\u00D7", k: "*",   kind: "op" },
    { t: "4",      k: "4",   kind: "num" },
    { t: "5",      k: "5",   kind: "num" },
    { t: "6",      k: "6",   kind: "num" },
    { t: "\u2212", k: "-",   kind: "op" },
    { t: "1",      k: "1",   kind: "num" },
    { t: "2",      k: "2",   kind: "num" },
    { t: "3",      k: "3",   kind: "num" },
    { t: "+",      k: "+",   kind: "op" },
    { t: "\u00B1", k: "NEG", kind: "fn" },
    { t: "0",      k: "0",   kind: "num" },
    { t: ",",      k: ".",   kind: "num" },
    { t: "=",      k: "=",   kind: "eq" }
  ]

  // texto bonito: * vira ×, / vira ÷, - vira −, . vira ,
  function calcShow(t) {
    return String(t)
      .replace(/\*/g, "\u00D7")
      .replace(/\//g, "\u00F7")
      .replace(/-/g, "\u2212")
      .replace(/\./g, ",");
  }

  function calcFmt(v) {
    if (!isFinite(v))
      throw new Error("inf");

    return Number(v.toPrecision(12)).toString();
  }

  // analisador recursivo: + - * / ^ % ( ) e sinal unário.
  // "100 + 10%" = 110 (a % depois de + ou - é sobre o valor da esquerda).
  function calcEval(str) {
    const t = str.match(/\d+\.?\d*|\.\d+|[-+*\/^()%]/g) || [];
    let i = 0;

    const peek = () => t[i];

    let expr;

    const atom = () => {
      const x = t[i++];

      if (x === "(") {
        const v = expr();

        if (peek() === ")")
          i++;

        return v;
      }

      if (x === undefined)
        throw new Error("sintaxe");

      const n = parseFloat(x);

      if (isNaN(n))
        throw new Error("sintaxe");

      return n;
    };

    const postfix = () => {
      let v = atom();

      while (peek() === "%") {
        i++;
        v = v / 100;
      }

      return v;
    };

    let factor;

    const power = () => {
      const b = postfix();

      if (peek() === "^") {
        i++;
        return Math.pow(b, factor());
      }

      return b;
    };

    factor = () => {
      if (peek() === "-") {
        i++;
        return -factor();
      }

      if (peek() === "+") {
        i++;
        return factor();
      }

      return power();
    };

    const term = () => {
      let v = factor();

      while (peek() === "*" || peek() === "/") {
        const o = t[i++];
        const r = factor();

        if (o === "/" && r === 0)
          throw new Error("div0");

        v = o === "*" ? v * r : v / r;
      }

      return v;
    };

    expr = () => {
      let v = term();

      while (peek() === "+" || peek() === "-") {
        const o = t[i++];
        let r = term();

        if (t[i - 1] === "%")
          r = v * r;

        v = o === "+" ? v + r : v - r;
      }

      return v;
    };

    const result = expr();

    if (i < t.length)
      throw new Error("sintaxe");

    return result;
  }

  // prévia do resultado enquanto você digita
  readonly property string calcLive: {
    if (calcExpr === "" || calcDone || calcErr)
      return "";

    let e = calcExpr;

    while (e.length > 0 && "+-*/^(".indexOf(e.charAt(e.length - 1)) >= 0)
      e = e.slice(0, -1);

    if (e === "")
      return "";

    try {
      return calcFmt(calcEval(e));
    } catch (x) {
      return "";
    }
  }

  function calcClear() {
    calcExpr = "";
    calcHist = "";
    calcDone = false;
    calcErr = false;
    calcErrMsg = "";
  }

  function calcEquals() {
    if (calcExpr === "")
      return;

    let e = calcExpr;

    while (e.length > 0 && "+-*/^(".indexOf(e.charAt(e.length - 1)) >= 0)
      e = e.slice(0, -1);

    if (e === "")
      return;

    try {
      const r = calcFmt(calcEval(e));

      calcHist = e + " =";
      calcExpr = r;
      calcDone = true;
      calcErr = false;
    } catch (x) {
      calcErr = true;
      calcErrMsg = x.message === "div0" ? "Divisão por zero" : "Expressão inválida";
      calcExpr = "";
      calcDone = false;
    }
  }

  function calcNegate() {
    if (calcDone) {
      calcExpr = calcExpr.charAt(0) === "-" ? calcExpr.slice(1) : "-" + calcExpr;
      return;
    }

    let m = /\(-(\d+\.?\d*)\)$/.exec(calcExpr);

    if (m) {
      calcExpr = calcExpr.slice(0, m.index) + m[1];
      return;
    }

    m = /(\d+\.?\d*)$/.exec(calcExpr);

    if (m)
      calcExpr = calcExpr.slice(0, m.index) + "(-" + m[1] + ")";
    else if (calcExpr === "")
      calcExpr = "-";
  }

  function calcDecimal() {
    if (calcDone) {
      calcExpr = "0.";
      calcHist = "";
      calcDone = false;
      return;
    }

    if (/[)%]$/.test(calcExpr))
      return;

    const m = /(\d*\.?\d*)$/.exec(calcExpr)[1];

    if (m.indexOf(".") >= 0)
      return;

    calcExpr += m === "" ? "0." : ".";
  }

  function calcPress(k) {
    // depois de um erro, qualquer tecla recomeça do zero
    if (calcErr) {
      calcClear();

      if (k === "C" || k === "=" || k === "BS")
        return;
    }

    switch (k) {
    case "C":
      calcClear();
      return;

    case "BS":
      if (calcDone)
        calcClear();
      else
        calcExpr = calcExpr.slice(0, -1);

      return;

    case "=":
      calcEquals();
      return;

    case "NEG":
      calcNegate();
      return;

    case ".":
      calcDecimal();
      return;

    case "%":
      if (/[\d)%]$/.test(calcExpr)) {
        calcExpr += "%";
        calcDone = false;
        calcHist = "";
      }

      return;

    case ")":
      calcExpr += ")";
      calcDone = false;
      return;
    }

    if (/^\d$/.test(k) || k === "(") {
      // dígito logo depois de um resultado começa uma conta nova
      if (calcDone) {
        calcExpr = "";
        calcHist = "";
        calcDone = false;
      }

      calcExpr += k;
      return;
    }

    // operadores: + - * / ^
    calcDone = false;
    calcHist = "";

    if (calcExpr === "") {
      if (k === "-")
        calcExpr = "-";

      return;
    }

    const last = calcExpr.charAt(calcExpr.length - 1);

    if ("+-*/^".indexOf(last) >= 0) {
      // "5 × −" é permitido; fora isso, troca o operador
      if (k === "-" && "*/^".indexOf(last) >= 0)
        calcExpr += "-";
      else if (calcExpr.length > 1)
        calcExpr = calcExpr.slice(0, -1) + k;

      return;
    }

    if (last === "(" && k !== "-")
      return;

    calcExpr += k;
  }

  function calcMoveSel(dx, dy) {
    const col = calcSel % 4;
    const row = Math.floor(calcSel / 4);
    const nc = Math.max(0, Math.min(3, col + dx));
    const nr = Math.max(0, Math.min(4, row + dy));

    calcSel = nr * 4 + nc;
  }

  function handleCalcKey(e) {
    let ok = true;

    switch (e.key) {
    case Qt.Key_Escape:
      phone.view = "menu";
      break;

    case Qt.Key_Return:
    case Qt.Key_Enter:
      calcPress("=");
      break;

    case Qt.Key_Backspace:
      calcPress("BS");
      break;

    case Qt.Key_Delete:
      calcPress("C");
      break;

    case Qt.Key_Up:    calcMoveSel(0, -1); break;
    case Qt.Key_Down:  calcMoveSel(0, 1);  break;
    case Qt.Key_Left:  calcMoveSel(-1, 0); break;
    case Qt.Key_Right: calcMoveSel(1, 0);  break;

    default: {
      const t = e.text;

      if (t && t.length === 1) {
        if ("0123456789+-*/^()%".indexOf(t) >= 0)
          calcPress(t);
        else if (t === "x" || t === "X")
          calcPress("*");
        else if (t === "," || t === ".")
          calcPress(".");
        else if (t === "=")
          calcPress("=");
        else if (t === "c" || t === "C")
          calcPress("C");
        else
          ok = false;
      } else {
        ok = false;
      }
    }
    }

    if (ok)
      e.accepted = true;
  }
}
