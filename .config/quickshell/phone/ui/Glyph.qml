// ui/Glyph.qml — ícones desenhados em Canvas (grade 24x24)

import QtQuick

Canvas {
  property string kind: ""
  property color stroke: "white"
  property real lw: 2.0

  onKindChanged: requestPaint()
  onStrokeChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    const ctx = getContext("2d");
    ctx.clearRect(0, 0, width, height);
    ctx.save();
    ctx.scale(width / 24, height / 24);

    ctx.strokeStyle = stroke;
    ctx.fillStyle = stroke;
    ctx.lineWidth = lw;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    switch (kind) {
    case "prev":
      ctx.fillRect(4.5, 5, 2.6, 14);
      ctx.beginPath();
      ctx.moveTo(19.5, 5);
      ctx.lineTo(9, 12);
      ctx.lineTo(19.5, 19);
      ctx.closePath();
      ctx.fill();
      break;

    case "next":
      ctx.fillRect(16.9, 5, 2.6, 14);
      ctx.beginPath();
      ctx.moveTo(4.5, 5);
      ctx.lineTo(15, 12);
      ctx.lineTo(4.5, 19);
      ctx.closePath();
      ctx.fill();
      break;

    case "play":
      ctx.beginPath();
      ctx.moveTo(7, 4.5);
      ctx.lineTo(20, 12);
      ctx.lineTo(7, 19.5);
      ctx.closePath();
      ctx.fill();
      break;

    case "pause":
      ctx.fillRect(6, 5, 4, 14);
      ctx.fillRect(14, 5, 4, 14);
      break;

    case "note":
      ctx.beginPath();
      ctx.arc(7.5, 18, 3.3, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(17.5, 16, 3.3, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(10.4, 18);
      ctx.lineTo(10.4, 6);
      ctx.moveTo(20.4, 16);
      ctx.lineTo(20.4, 4);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(10.4, 6);
      ctx.lineTo(20.4, 4);
      ctx.lineTo(20.4, 8.2);
      ctx.lineTo(10.4, 10.2);
      ctx.closePath();
      ctx.fill();
      break;

    case "image":
      ctx.beginPath();
      ctx.moveTo(6, 3);
      ctx.lineTo(18, 3);
      ctx.arcTo(21, 3, 21, 6, 3);
      ctx.lineTo(21, 18);
      ctx.arcTo(21, 21, 18, 21, 3);
      ctx.lineTo(6, 21);
      ctx.arcTo(3, 21, 3, 18, 3);
      ctx.lineTo(3, 6);
      ctx.arcTo(3, 3, 6, 3, 3);
      ctx.closePath();
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(8.5, 8.5, 1.8, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(4, 18);
      ctx.lineTo(10, 12);
      ctx.lineTo(14, 16);
      ctx.lineTo(16.5, 13.5);
      ctx.lineTo(20, 17);
      ctx.stroke();
      break;

    case "folder":
      ctx.beginPath();
      ctx.moveTo(3, 6);
      ctx.lineTo(9.5, 6);
      ctx.lineTo(11.5, 8.5);
      ctx.lineTo(21, 8.5);
      ctx.lineTo(21, 19);
      ctx.lineTo(3, 19);
      ctx.closePath();
      ctx.fill();
      break;

    case "file":
      ctx.beginPath();
      ctx.moveTo(6, 3);
      ctx.lineTo(14, 3);
      ctx.lineTo(19, 8);
      ctx.lineTo(19, 21);
      ctx.lineTo(6, 21);
      ctx.closePath();
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(14, 3);
      ctx.lineTo(14, 8);
      ctx.lineTo(19, 8);
      ctx.stroke();
      break;

    case "timer":
      ctx.beginPath();
      ctx.arc(12, 13.5, 8, 0, Math.PI * 2);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(9.5, 2.8);
      ctx.lineTo(14.5, 2.8);
      ctx.moveTo(12, 2.8);
      ctx.lineTo(12, 5.5);
      ctx.moveTo(12, 13.5);
      ctx.lineTo(12, 9);
      ctx.moveTo(12, 13.5);
      ctx.lineTo(15.2, 15.4);
      ctx.stroke();
      break;

    case "screen":
      ctx.strokeRect(3, 4, 18, 12);
      ctx.beginPath();
      ctx.moveTo(12, 16);
      ctx.lineTo(12, 20);
      ctx.moveTo(8, 20);
      ctx.lineTo(16, 20);
      ctx.stroke();
      break;

    case "extend":
      ctx.strokeRect(2.5, 6.5, 8, 11);
      ctx.strokeRect(13.5, 6.5, 8, 11);
      break;

    case "mirror":
      ctx.strokeRect(2.5, 5.5, 13, 10);
      ctx.strokeRect(8.5, 9.5, 13, 10);
      break;

    case "calc":
      ctx.beginPath();
      ctx.rect(5, 3, 14, 18);
      ctx.stroke();
      ctx.fillRect(7.5, 5.5, 9, 3.5);

      for (const cy of [12.5, 16.5]) {
        for (const cx of [8, 12, 16])
          ctx.fillRect(cx - 0.9, cy - 0.9, 1.8, 1.8);
      }

      break;

    case "gear":
      ctx.beginPath();
      ctx.arc(12, 12, 3.2, 0, Math.PI * 2);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(12, 12, 6.4, 0, Math.PI * 2);
      ctx.stroke();

      for (let gi = 0; gi < 8; gi++) {
        const ga = gi * Math.PI / 4;

        ctx.beginPath();
        ctx.moveTo(12 + Math.cos(ga) * 6.4, 12 + Math.sin(ga) * 6.4);
        ctx.lineTo(12 + Math.cos(ga) * 9.4, 12 + Math.sin(ga) * 9.4);
        ctx.stroke();
      }

      break;

    case "wifi":
      ctx.beginPath();
      ctx.arc(12, 19.5, 1.3, 0, Math.PI * 2);
      ctx.fill();

      for (const wr of [4.6, 8.6, 12.6]) {
        ctx.beginPath();
        ctx.arc(12, 19.5, wr, Math.PI * 1.25, Math.PI * 1.75);
        ctx.stroke();
      }

      break;

    case "battery":
      ctx.beginPath();
      ctx.rect(3, 7, 16, 10);
      ctx.stroke();
      ctx.fillRect(20.2, 10.5, 2, 3);
      ctx.fillRect(5.4, 9.4, 9.2, 5.2);
      break;

    case "moon":
      ctx.beginPath();
      ctx.arc(12, 12, 8, 0, Math.PI * 2);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(12, 12, 8, Math.PI * 0.5, Math.PI * 1.5, false);
      ctx.closePath();
      ctx.fill();
      break;

    case "monitor":
      ctx.beginPath();
      ctx.rect(3, 4.5, 18, 11.5);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(8, 20);
      ctx.lineTo(16, 20);
      ctx.moveTo(12, 16);
      ctx.lineTo(12, 20);
      ctx.stroke();
      break;

    case "pin":
      ctx.beginPath();
      ctx.moveTo(12, 21);
      ctx.lineTo(6.3, 12.8);
      ctx.arc(12, 9.5, 6.6, Math.PI * 0.82, Math.PI * 0.18, false);
      ctx.closePath();
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(12, 9.5, 2.2, 0, Math.PI * 2);
      ctx.stroke();
      break;

    case "keyboard":
      ctx.beginPath();
      ctx.rect(2.5, 6.5, 19, 11);
      ctx.stroke();

      for (const kx of [5.4, 9.2, 13, 16.8])
        ctx.fillRect(kx, 9.4, 1.9, 1.9);

      ctx.fillRect(7, 13.4, 10, 1.9);
      break;

    case "about":
      ctx.beginPath();
      ctx.arc(12, 12, 9, 0, Math.PI * 2);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(12, 11);
      ctx.lineTo(12, 17);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(12, 7.8, 1.1, 0, Math.PI * 2);
      ctx.fill();
      break;

    case "chat":
      ctx.beginPath();
      ctx.moveTo(5, 4.5);
      ctx.lineTo(19, 4.5);
      ctx.quadraticCurveTo(21, 4.5, 21, 6.5);
      ctx.lineTo(21, 13.5);
      ctx.quadraticCurveTo(21, 15.5, 19, 15.5);
      ctx.lineTo(11, 15.5);
      ctx.lineTo(6.5, 19.5);
      ctx.lineTo(6.5, 15.5);
      ctx.lineTo(5, 15.5);
      ctx.quadraticCurveTo(3, 15.5, 3, 13.5);
      ctx.lineTo(3, 6.5);
      ctx.quadraticCurveTo(3, 4.5, 5, 4.5);
      ctx.closePath();
      ctx.stroke();

      for (const cx of [8, 12, 16]) {
        ctx.beginPath();
        ctx.arc(cx, 10, 1.15, 0, Math.PI * 2);
        ctx.fill();
      }

      break;

    case "clipboard":
      ctx.strokeRect(5, 4.5, 14, 16.5);
      ctx.strokeRect(9, 2.5, 6, 4);
      ctx.beginPath();
      ctx.moveTo(8.5, 11);
      ctx.lineTo(15.5, 11);
      ctx.moveTo(8.5, 14.5);
      ctx.lineTo(15.5, 14.5);
      ctx.moveTo(8.5, 18);
      ctx.lineTo(13, 18);
      ctx.stroke();
      break;

    case "download":
      ctx.beginPath();
      ctx.moveTo(12, 3.5);
      ctx.lineTo(12, 14.5);
      ctx.moveTo(7.5, 10.5);
      ctx.lineTo(12, 15);
      ctx.lineTo(16.5, 10.5);
      ctx.moveTo(4.5, 15.5);
      ctx.lineTo(4.5, 20);
      ctx.lineTo(19.5, 20);
      ctx.lineTo(19.5, 15.5);
      ctx.stroke();
      break;

    case "calendar":
      ctx.strokeRect(3.5, 5, 17, 15.5);
      ctx.beginPath();
      ctx.moveTo(3.5, 10);
      ctx.lineTo(20.5, 10);
      ctx.moveTo(8, 2.8);
      ctx.lineTo(8, 7);
      ctx.moveTo(16, 2.8);
      ctx.lineTo(16, 7);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(12, 13);
      ctx.lineTo(12, 16.2);
      ctx.lineTo(14.4, 17.6);
      ctx.stroke();
      break;

    case "terminal":
      ctx.beginPath();
      ctx.moveTo(4.5, 7);
      ctx.lineTo(10.5, 12);
      ctx.lineTo(4.5, 17);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(12.5, 18);
      ctx.lineTo(19.5, 18);
      ctx.stroke();
      break;

    case "bluetooth":
      ctx.beginPath();
      ctx.moveTo(6.5, 7.5);
      ctx.lineTo(17.5, 16.5);
      ctx.lineTo(12, 21);
      ctx.lineTo(12, 3);
      ctx.lineTo(17.5, 7.5);
      ctx.lineTo(6.5, 16.5);
      ctx.stroke();
      break;

    case "bolt":
      ctx.beginPath();
      ctx.moveTo(13.5, 2);
      ctx.lineTo(5, 13.5);
      ctx.lineTo(11, 13.5);
      ctx.lineTo(10, 22);
      ctx.lineTo(19, 10);
      ctx.lineTo(13, 10);
      ctx.closePath();
      ctx.fill();
      break;

    case "snake":
      ctx.lineWidth = 3.2;
      ctx.beginPath();
      ctx.moveTo(19, 5.5);
      ctx.lineTo(9, 5.5);
      ctx.bezierCurveTo(4, 5.5, 4, 12, 9, 12);
      ctx.lineTo(15, 12);
      ctx.bezierCurveTo(20, 12, 20, 18.5, 15, 18.5);
      ctx.lineTo(5, 18.5);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(19.5, 5.5, 1.6, 0, Math.PI * 2);
      ctx.fill();
      break;

    case "check":
      ctx.beginPath();
      ctx.moveTo(5, 12.5);
      ctx.lineTo(10, 17.5);
      ctx.lineTo(19, 7);
      ctx.stroke();
      break;
    }

    ctx.restore();
  }
}
