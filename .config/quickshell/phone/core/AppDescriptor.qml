// core/AppDescriptor.qml — metadados de um app do celular usados pelo registro e pelo menu.

import QtQuick

QtObject {
  property string appId: ""
  property string viewId: ""
  property var logic: null
  property string name: ""
  property string glyph: ""
  property int glyphSize: 21
  property color tileColor: "transparent"
  property color glyphColor: "white"
  property bool roundIcon: false
  property var keywords: []
  property bool showInMenu: false
  property bool capturesKeys: false
  property var enterAction: null
}
