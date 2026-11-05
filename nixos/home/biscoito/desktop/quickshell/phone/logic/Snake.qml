// logic/Snake.qml — Jogo da cobrinha (morango = simples, chocolate = especial)
//
// Módulo de lógica (sem visual). Instanciado em shell.qml como "snake".
// Acesso de fora:  phone.snake.<membro>
//
// Morango   : +1 ponto, cresce 1 casa.
// Chocolate : +5 pontos, cresce 3 casas. Aparece a cada `cadaQuantos` morangos
//             e some sozinho se ninguém pegar a tempo (`vidaChocolate` passos).

import QtQuick
import Quickshell

Scope {
  id: self

  required property var phone

  // tabuleiro
  property int cols: 16
  property int rows: 13
  property bool paredesMatam: true

  // "pronto" | "jogando" | "pausado" | "fim"
  property string estado: "pronto"

  property var corpo: []          // [{x, y}], cabeça no índice 0
  property var morango: null      // {x, y}
  property var chocolate: null    // {x, y, vida} ou null

  property int pontos: 0
  property int recorde: 0         // vale até fechar o shell
  property int comidos: 0         // morangos comidos na partida
  property int cadaQuantos: 5
  property int vidaChocolate: 36

  // direção em que a cobra andou por último
  property int dirX: 1
  property int dirY: 0

  property int _proxX: 1
  property int _proxY: 0
  property int _crescer: 0

  // textos das softkeys
  readonly property string snakeSoftCenter:
    estado === "jogando" ? "Pausar"
      : estado === "pausado" ? "Continuar"
      : "Jogar"

  signal mudou()

  // só roda com a tela da cobrinha aberta: sair do app congela a partida
  Timer {
    repeat: true
    running:
      self.estado === "jogando"
      && self.phone.view === "snake"
      && self.phone.panelOpen

    interval: Math.max(65, 150 - self.comidos * 3)

    onTriggered: self.passo()
  }

  Component.onCompleted: reiniciar()

  // chamado pelo shell.qml quando a view vira "snake"
  function snakeEnter() {
    if (estado === "jogando")
      estado = "pausado";
    else if (estado === "fim")
      reiniciar();

    mudou();
  }

  function reiniciar() {
    corpo = [{ x: 5, y: 6 }, { x: 4, y: 6 }, { x: 3, y: 6 }];
    dirX = 1; dirY = 0;
    _proxX = 1; _proxY = 0;
    _crescer = 0;
    pontos = 0;
    comidos = 0;
    chocolate = null;
    morango = null;
    sortearMorango();
    estado = "pronto";
    mudou();
  }

  function ocupado(x, y) {
    for (let i = 0; i < corpo.length; i++) {
      if (corpo[i].x === x && corpo[i].y === y)
        return true;
    }

    if (morango && morango.x === x && morango.y === y)
      return true;

    if (chocolate && chocolate.x === x && chocolate.y === y)
      return true;

    return false;
  }

  function celulaLivre() {
    for (let t = 0; t < 400; t++) {
      const x = Math.floor(Math.random() * cols);
      const y = Math.floor(Math.random() * rows);

      if (!ocupado(x, y))
        return { x: x, y: y };
    }

    return null;
  }

  function sortearMorango() {
    const c = celulaLivre();
    morango = c ? { x: c.x, y: c.y } : null;
  }

  function passo() {
    dirX = _proxX;
    dirY = _proxY;

    let nx = corpo[0].x + dirX;
    let ny = corpo[0].y + dirY;

    if (paredesMatam) {
      if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) {
        terminar();
        return;
      }
    } else {
      nx = (nx + cols) % cols;
      ny = (ny + rows) % rows;
    }

    const comeuMorango = morango && morango.x === nx && morango.y === ny;
    const comeuChoc = chocolate && chocolate.x === nx && chocolate.y === ny;

    if (comeuMorango)
      _crescer += 1;

    if (comeuChoc)
      _crescer += 3;

    // a cauda sai do lugar, a não ser que a cobra esteja crescendo
    const limite = _crescer > 0 ? corpo.length : corpo.length - 1;

    for (let i = 0; i < limite; i++) {
      if (corpo[i].x === nx && corpo[i].y === ny) {
        terminar();
        return;
      }
    }

    const novo = [{ x: nx, y: ny }].concat(corpo);

    if (_crescer > 0)
      _crescer--;
    else
      novo.pop();

    corpo = novo;

    if (comeuMorango) {
      pontos += 1;
      comidos += 1;
      sortearMorango();

      if (comidos % cadaQuantos === 0 && !chocolate) {
        const c = celulaLivre();

        if (c)
          chocolate = { x: c.x, y: c.y, vida: vidaChocolate };
      }
    }

    if (comeuChoc) {
      pontos += 5;
      chocolate = null;
    } else if (chocolate) {
      const v = chocolate.vida - 1;

      chocolate = v > 0
        ? { x: chocolate.x, y: chocolate.y, vida: v }
        : null;
    }

    mudou();
  }

  function terminar() {
    estado = "fim";

    if (pontos > recorde)
      recorde = pontos;

    mudou();
  }

  function virar(dx, dy) {
    if (estado === "fim")
      return;

    // não dá meia-volta em cima de si mesma
    if (dx === -dirX && dy === -dirY)
      return;

    _proxX = dx;
    _proxY = dy;

    if (estado === "pronto")
      estado = "jogando";
  }

  // OK / Enter / Espaço
  function alternar() {
    if (estado === "pronto")
      estado = "jogando";
    else if (estado === "jogando")
      estado = "pausado";
    else if (estado === "pausado")
      estado = "jogando";
    else if (estado === "fim") {
      reiniciar();
      estado = "jogando";
    }

    mudou();
  }

  // teclado: setas/WASD viram, Enter/Espaço pausa, Esc pausa e depois sai
  function handleSnakeKey(e) {
    switch (e.key) {
    case Qt.Key_Up:    case Qt.Key_W: virar(0, -1); break;
    case Qt.Key_Down:  case Qt.Key_S: virar(0, 1);  break;
    case Qt.Key_Left:  case Qt.Key_A: virar(-1, 0); break;
    case Qt.Key_Right: case Qt.Key_D: virar(1, 0);  break;

    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Space:
    case Qt.Key_P:
      alternar();
      break;

    case Qt.Key_Escape:
      if (estado === "jogando") {
        estado = "pausado";
        mudou();
      } else {
        phone.view = "menu";
      }
      break;

    default:
      return;
    }

    mudou();
    e.accepted = true;
  }
}
