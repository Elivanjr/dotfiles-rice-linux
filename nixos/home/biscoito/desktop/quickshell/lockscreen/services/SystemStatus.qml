import QtQuick
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
    id: service
    visible: false

    property int batteryPercent: Math.round((UPower.displayDevice.percentage || 0) * 100)
    property bool batteryCharging: UPower.displayDevice.state === UPowerDeviceState.Charging
    property real tempCelsius: 0
    property var wifiDevice: {
        for (var i = 0; i < Networking.devices.values.length; i++) {
            if (Networking.devices.values[i].type === DeviceType.Wifi)
                return Networking.devices.values[i]
        }
        return null
    }
    property string wifiSsid: {
        if (!service.wifiDevice) return "Sem wifi"
        var networks = service.wifiDevice.networks.values
        for (var i = 0; i < networks.length; i++) {
            if (networks[i].connected) return networks[i].name
        }
        return "Desconectado"
    }
    property int volumePercent: Math.round((Pipewire.defaultAudioSink?.audio?.volume || 0) * 100)
    property bool volumeMuted: Pipewire.defaultAudioSink?.audio?.muted || false

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    Process {
        id: sensorsProc
        command: ["sensors", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    for (var chip in data) {
                        if (chip.indexOf("coretemp") === -1) continue
                        for (var sensorName in data[chip]) {
                            if (sensorName.indexOf("Package id") === -1) continue
                            for (var field in data[chip][sensorName]) {
                                if (field.indexOf("_input") !== -1) {
                                    service.tempCelsius = Math.round(data[chip][sensorName][field])
                                    return
                                }
                            }
                        }
                    }
                } catch (error) {
                    console.log("Erro lendo temperatura (sensors -j):", error)
                }
            }
        }
    }

    Timer { interval: 3000; running: true; repeat: true; onTriggered: sensorsProc.running = true }

    function batteryIcon() {
        if (service.batteryCharging) return "\uf0e7"
        if (service.batteryPercent >= 87) return "\uf240"
        if (service.batteryPercent >= 62) return "\uf241"
        if (service.batteryPercent >= 37) return "\uf242"
        if (service.batteryPercent >= 12) return "\uf243"
        return "\uf244"
    }
    function volumeIcon() {
        if (service.volumeMuted || service.volumePercent === 0) return "\uf026"
        return service.volumePercent < 50 ? "\uf027" : "\uf028"
    }
    function tempIcon() {
        if (service.tempCelsius >= 80) return "\uf2c7"
        if (service.tempCelsius >= 60) return "\uf2c8"
        if (service.tempCelsius >= 40) return "\uf2c9"
        if (service.tempCelsius >= 20) return "\uf2ca"
        return "\uf2cb"
    }
}
