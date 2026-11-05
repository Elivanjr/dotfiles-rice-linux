// MarkdownContent.qml — renderização leve de Markdown com blocos de código nativos.
import QtQuick
import Quickshell

Column {
  id: root

  property string content: ""
  property color textColor: "#e6e1e5"
  property color mutedColor: "#938f99"
  property color blockColor: "#211f26"
  property color borderColor: "#49454f"
  property color accentColor: "#d0bcff"
  property string fontFamily: "JetBrainsMono NF"
  property int fontPixelSize: 13

  spacing: 8
  width: 400

  // Divide a resposta em partes de Markdown e blocos cercados por ``` ou ~~~.
  // Uma cerca ainda aberta durante o streaming é tratada como bloco em andamento.
  function parseContent(source) {
    const result = [];
    const fence = /(^|\n)(```|~~~)([^\n]*)\n([\s\S]*?)(?:\n\2\s*(?:\n|$)|$)/g;
    let last = 0;
    let match;

    while ((match = fence.exec(source)) !== null) {
      const start = match.index + match[1].length;
      const end = fence.lastIndex;

      if (start > last) {
        const prose = source.slice(last, start);
        if (prose !== "") result.push({ type: "markdown", text: prose });
      }

      const language = match[3].trim().split(/\s+/)[0] || "código";
      let code = match[4];
      if (code.endsWith("\n")) code = code.slice(0, -1);

      result.push({
        type: "code",
        text: code,
        language: language
      });

      last = end;
    }

    if (last < source.length) {
      result.push({ type: "markdown", text: source.slice(last) });
    }

    if (result.length === 0) {
      result.push({ type: "markdown", text: source });
    }

    return result;
  }

  property var segments: parseContent(content)

  Repeater {
    model: root.segments

    delegate: Loader {
      required property var modelData
      width: root.width
      sourceComponent: modelData.type === "code" ? codeComponent : markdownComponent

      onLoaded: {
        if (!item) return;
        item.width = width;

        if (modelData.type === "code") {
          item.code = modelData.text;
          item.language = modelData.language;
          item.textColor = root.textColor;
          item.mutedColor = root.mutedColor;
          item.blockColor = root.blockColor;
          item.borderColor = root.borderColor;
          item.accentColor = root.accentColor;
          item.fontFamily = root.fontFamily;
          item.fontPixelSize = root.fontPixelSize;
        } else {
          item.text = modelData.text;
          item.textColor = root.textColor;
          item.fontFamily = root.fontFamily;
          item.fontPixelSize = root.fontPixelSize;
        }
      }

      onWidthChanged: {
        if (item) item.width = width;
      }

      implicitHeight: item ? item.implicitHeight : 0
    }
  }

  Component {
    id: markdownComponent

    TextEdit {
      property color textColor: "#e6e1e5"
      property string fontFamily: "JetBrainsMono NF"
      property int fontPixelSize: 13

      textFormat: TextEdit.MarkdownText
      wrapMode: TextEdit.Wrap
      readOnly: true
      selectByMouse: true
      color: textColor
      font.family: fontFamily
      font.pixelSize: fontPixelSize
      height: contentHeight

      onLinkActivated: (link) => Qt.openUrlExternally(link)
    }
  }

  Component {
    id: codeComponent

    CodeBlock {}
  }
}
