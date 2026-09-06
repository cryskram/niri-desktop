// Notifications — via makoctl or Quickshell.Notifications (placeholder, hides if no daemon)
import Quickshell.Io
import QtQuick

Text {
    id: root
    color: "#c0caf5"
    font.family: "Inter"
    font.pixelSize: 10
    visible: display !== ""
    property string display: ""
    text: display

    Process {
        id: proc
        command: ["sh", "-c", "makoctl list 2>/dev/null | grep -c 'Notification ' | head -1; echo ---; makoctl mode 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.trim().split("\n")
                    const countStr = (parts[0] || "").trim()
                    const mode = (parts[1] || "").trim().toLowerCase()
                    const count = parseInt(countStr, 10)
                    if (mode.includes("do-not-disturb") || mode.includes("dnd")) {
                        root.display = "🔕"
                        root.color = "#787c99"
                    } else if (!isNaN(count) && count > 0) {
                        root.display = `🔔 ${count}`
                        root.color = "#7dcfff"
                    } else {
                        // No notifications → hide to save space (per RICE §8 secondary belongs in panel)
                        root.display = ""
                    }
                } catch (e) {
                    root.display = ""
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: proc.running = true
    }
    Component.onCompleted: proc.running = true
}
