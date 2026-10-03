import QtQuick
import Quickshell

QtObject {
    id: root
    property var telemetry: null
    Component.onCompleted: {
        // Quickshell rewrites relative imports outside its config directory.
        var directory = Quickshell.env("BTOP_PLUGIN_ROOT") || Quickshell.env("PWD")
        var component = Qt.createComponent("file:" + directory + "/Telemetry.qml")
        if (component.status !== Component.Ready) {
            console.error(component.errorString())
            Qt.quit()
            return
        }
        telemetry = component.createObject(root, {
            updateMs: Number(Quickshell.env("BTOP_SMOKE_UPDATE_MS") || 1000),
            active: true
        })
    }
    property Timer idle: Timer {
        interval: Number(Quickshell.env("BTOP_SMOKE_IDLE_AFTER_MS") || 0)
        running: interval > 0 && root.telemetry !== null
        onTriggered: root.telemetry.active = false
    }
    property Timer progress: Timer {
        interval: 1000
        repeat: true
        running: root.telemetry !== null
        onTriggered: console.log("TELEMETRY " + JSON.stringify({
            time: Date.now(), updateMs: telemetry.updateMs, active: telemetry.active,
            lastSample: telemetry._lastSample, cpu: telemetry.cpuUsage,
            memory: telemetry.memoryUsage, temperature: telemetry.cpuTemperature,
            gpus: telemetry.gpus,
            errors: telemetry.backendErrors
        }))
    }
    property Timer stop: Timer {
        interval: Number(Quickshell.env("BTOP_SMOKE_MS") || 6500)
        running: true
        onTriggered: Qt.quit()
    }
}
