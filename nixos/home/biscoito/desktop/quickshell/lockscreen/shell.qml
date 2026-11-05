import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    WlSessionLock {
        id: sessionLock

        // Começa desbloqueado.
        // A instância fica rodando permanentemente,
        // mas só bloqueia quando lock() for chamado via IPC.
        locked: false

        WlSessionLockSurface {
            LockScreen {
                anchors.fill: parent

                onUnlocked: {
                    sessionLock.locked = false
                }
            }
        }
    }

    IpcHandler {
        target: "lockscreen"

        function lock(): void {
            sessionLock.locked = true
        }

        function toggle(): void {
            sessionLock.locked = !sessionLock.locked
        }

        // Apenas para teste.
        // Depois vamos remover e deixar somente
        // o desbloqueio real por senha.
        function unlock(): void {
            sessionLock.locked = false
        }
    }
}
