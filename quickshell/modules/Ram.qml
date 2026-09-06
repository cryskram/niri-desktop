// Ram — live RAM usage via /proc/meminfo
import Quickshell.Io
import QtQuick

Text {
    id: root
    color: "#c0caf5"
    font.family: "Inter"
    font.pixelSize: 10
    property string display: "RAM —%"

    text: display

    Process {
        id: proc
        command: ["sh", "-c", "grep -E 'MemTotal|MemAvailable' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const lines = text.trim().split("\n")
                    let total = 0, avail = 0
                    for (const line of lines) {
                        const m = line.match(/(\d+)/)
                        if (!m) continue
                        const v = parseInt(m[1], 10)
                        if (line.includes("MemTotal")) total = v
                        else if (line.includes("MemAvailable")) avail = v
                    }
                    if (total > 0) {
                        const used = total - avail
                        const pct = Math.round((used / total) * 100)
                        root.display = `RAM ${pct}%`
                        root.color = pct > 85 ? "#f7768e" : pct > 70 ? "#e0af68" : "#c0caf5"
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: proc.running = true
    }
    Component.onCompleted: proc.running = true
}
