// views/SnakeView.qml — Cobrinha (morango = simples, chocolate = especial)

import QtQuick
import "../ui"

ViewBase {
  id: snakeView

  visible: phone.view === "snake"

  readonly property var game: phone.snake

  // pontos (no lugar do título rosa do menu)
  Text {
    x: s(10)
    y: s(46) - height / 2

    text: "Pontos " + snakeView.game.pontos
    color: phone.pink
    font.family: phone.fontUi
    font.pixelSize: s(19)
  }

  Text {
    x: lcd.width - width - s(10)
    y: s(46) - height / 2

    text: "Recorde " + snakeView.game.recorde
    color: phone.txtMuted
    font.family: phone.fontUi
    font.pixelSize: s(12)
  }

  // tempo que falta pro chocolate sumir
  Rectangle {
    visible: snakeView.game.chocolate !== null

    x: s(10)
    y: s(58)
    width: lcd.width - s(20)
    height: s(3)
    radius: height / 2
    color: phone.ov(0.1)

    Rectangle {
      height: parent.height
      radius: height / 2
      color: "#a0623a"

      width: snakeView.game.chocolate
        ? parent.width * snakeView.game.chocolate.vida / snakeView.game.vidaChocolate
        : 0
    }
  }

  Item {
    id: board

    x: s(8)
    y: s(64)
    width: lcd.width - s(16)
    height: s(224)

    Canvas {
      id: tela

      anchors.fill: parent

      readonly property real cel:
        Math.floor(Math.min(width / snakeView.game.cols, height / snakeView.game.rows))

      onCelChanged: requestPaint()

      Connections {
        target: snakeView.game

        function onMudou() {
          tela.requestPaint();
        }
      }

      // tema claro/escuro do celular
      Connections {
        target: phone

        function onThemeDarkChanged() {
          tela.requestPaint();
        }
      }

      onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const g = snakeView.game;
        const c = cel;

        if (c <= 0)
          return;

        const ox = Math.floor((width - c * g.cols) / 2);
        const oy = Math.floor((height - c * g.rows) / 2);

        // tabuleiro em xadrez
        for (let y = 0; y < g.rows; y++) {
          for (let x = 0; x < g.cols; x++) {
            ctx.fillStyle = ((x + y) % 2 === 0) ? phone.ov(0.05) : phone.ov(0.09);
            ctx.fillRect(ox + x * c, oy + y * c, c, c);
          }
        }

        // morango
        if (g.morango) {
          const mx = ox + g.morango.x * c + c / 2;
          const my = oy + g.morango.y * c + c / 2;
          const r = c * 0.36;
          const sd = Math.max(1, c * 0.07);

          ctx.fillStyle = "#e0314b";
          ctx.beginPath();
          ctx.arc(mx, my + c * 0.04, r, 0, Math.PI * 2);
          ctx.fill();

          ctx.fillStyle = "#4caf50";
          ctx.fillRect(mx - r * 0.6, my - r * 1.05, r * 1.2, r * 0.35);

          ctx.fillStyle = "#ffe3a8";
          ctx.fillRect(mx - r * 0.45, my - r * 0.1, sd, sd);
          ctx.fillRect(mx + r * 0.3, my - r * 0.1, sd, sd);
          ctx.fillRect(mx - r * 0.05, my + r * 0.3, sd, sd);
        }

        // chocolate (pisca quando está quase sumindo)
        if (g.chocolate && !(g.chocolate.vida <= 10 && g.chocolate.vida % 2 === 0)) {
          const cx0 = ox + g.chocolate.x * c;
          const cy0 = oy + g.chocolate.y * c;
          const m = c * 0.12;

          ctx.fillStyle = "#5a3220";
          ctx.fillRect(cx0 + m, cy0 + m, c - 2 * m, c - 2 * m);

          ctx.strokeStyle = "#3b1f12";
          ctx.lineWidth = Math.max(1, c * 0.06);
          ctx.beginPath();
          ctx.moveTo(cx0 + c / 2, cy0 + m);
          ctx.lineTo(cx0 + c / 2, cy0 + c - m);
          ctx.moveTo(cx0 + m, cy0 + c / 2);
          ctx.lineTo(cx0 + c - m, cy0 + c / 2);
          ctx.stroke();

          ctx.fillStyle = "#8a5638";
          ctx.fillRect(cx0 + m, cy0 + m, c * 0.18, c * 0.18);
        }

        // cobra (do rabo pra cabeça)
        for (let i = g.corpo.length - 1; i >= 0; i--) {
          const p = g.corpo[i];

          ctx.fillStyle = i === 0 ? phone.txt : phone.cOk;
          ctx.fillRect(ox + p.x * c + 1, oy + p.y * c + 1, c - 2, c - 2);
        }

        // olhos
        if (g.corpo.length > 0) {
          const h = g.corpo[0];
          const hx = ox + h.x * c + c / 2;
          const hy = oy + h.y * c + c / 2;
          const e = Math.max(2, c * 0.13);

          ctx.fillStyle = "#10201a";

          for (let k = -1; k <= 1; k += 2) {
            ctx.fillRect(
              hx + g.dirX * c * 0.18 + (-g.dirY) * k * c * 0.2 - e / 2,
              hy + g.dirY * c * 0.18 + g.dirX * k * c * 0.2 - e / 2,
              e, e
            );
          }
        }
      }
    }

    // pronto / pausado / fim
    Rectangle {
      anchors.fill: parent
      visible: snakeView.game.estado !== "jogando"
      radius: s(4)
      color: phone.veil(0.72)

      Column {
        anchors.centerIn: parent
        spacing: s(6)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter

          text:
            snakeView.game.estado === "pronto" ? "Cobrinha"
              : snakeView.game.estado === "pausado" ? "Pausado"
              : "Fim de jogo"

          color: phone.pink
          font.family: phone.fontUi
          font.pixelSize: s(22)
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: snakeView.game.estado === "fim"

          text: snakeView.game.pontos + " pontos"
          color: phone.txt
          font.family: phone.fontUi
          font.pixelSize: s(15)
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: snakeView.game.estado === "pronto"

          text: "Morango +1   Chocolate +5"
          color: phone.txtMuted
          font.family: phone.fontUi
          font.pixelSize: s(11)
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter

          text: snakeView.game.estado === "pronto" ? "Setas ou OK para começar"
              : snakeView.game.estado === "pausado" ? "OK continua, Esc sai"
              : "OK para jogar de novo"

          color: phone.txtMuted
          font.family: phone.fontUi
          font.pixelSize: s(11)
        }
      }
    }
  }
}
