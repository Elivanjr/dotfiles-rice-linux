// core/ShellRunner.qml — executa um comando do sistema e entrega código de saída e linhas limpas.

import Quickshell
import Quickshell.Io

Scope {
  id: self

  property bool busy: false

  property var doneCallback: null

  function run(label, script, args, env, okMessage, onDone) {
    if (busy)
      return false;

    busy = true;
    doneCallback = typeof onDone === "function" ? onDone : null;

    commandProc.environment = env || ({});
    commandProc.command = [
      "sh", "-c",
      "( " + script + "\n) 2>&1\necho \"__RC__=$?\"",
      "sh"
    ].concat(args || []);
    commandProc.running = true;
    return true;
  }

  Process {
    id: commandProc

    stdout: StdioCollector {
      onStreamFinished: {
        const lines = this.text.split("\n");
        const output = [];
        let rc = 1;

        for (const line of lines) {
          if (line.indexOf("__RC__=") === 0) {
            const parsed = parseInt(line.slice(7));
            if (Number.isFinite(parsed))
              rc = parsed;
          } else if (line.trim() !== "") {
            const clean = line.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").trim();
            if (clean !== "")
              output.push(clean);
          }
        }

        self.busy = false;
        const callback = self.doneCallback;
        self.doneCallback = null;
        if (callback)
          callback(rc, output);
      }
    }

    onExited: commandProc.environment = ({})
  }
}
