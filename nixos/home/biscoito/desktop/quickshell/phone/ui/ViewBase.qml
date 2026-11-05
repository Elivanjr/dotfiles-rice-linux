// ui/ViewBase.qml — base de todas as telas/peças que ficam sobre o celular
//
// Preenche o pai (a tela de vidro "lcd" ou o palco "stage") e entrega os
// mesmos atalhos que o shell.qml tinha: s(), fx(), fy() e lcd.
// Quem usa só precisa passar:  XxxView { phone: root }

import QtQuick

Item {
  required property var phone

  anchors.fill: parent

  readonly property Item lcd: phone.lcdItem

  function s(v) { return phone.s(v); }
  function fx(v) { return phone.fx(v); }
  function fy(v) { return phone.fy(v); }
}
