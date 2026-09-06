// Cpu — live CPU usage via /proc/stat ( polled via niri-style Process )
import Quickshell.Io
import QtQuick

Text {
    id: root
    color: "#c0caf5"
    font.family: "Inter"
    font.pixelSize: 10

    property int prevIdle: 0
    property int prevTotal: 0
    property string display: "CPU —%"

    text: display

    Process {
        id: proc
        command: ["sh", "-c", "head -n1 /proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // cpu  123 456 789 1011 ...
                    const parts = text.trim().split(/\s+/)
                    if (parts.length < 5 || parts[0] !== "cpu")
                        return
                    const vals = parts.slice(1).map(v => parseInt(v, 10))
                    const idle = vals[3] + (vals[4] || 0) // idle + iowait
                    const total = vals.reduce((a, b) => a + b, 0)
                    if (root.prevTotal !== 0) {
                        const diffIdle = idle - root.prevIdle
                        const diffTotal = total - root.prevTotal
                        const usage = diffTotal > 0 ? Math.round((1 - diffIdle / diffTotal) * 100) : 0
                        root.display = `CPU ${usage}%`
                        // Storm warning color at high load
                        root.color = usage > 85 ? "#f7768e" : usage > 65 ? "#e0af68" : "#c0caf5"
                    }
                    root.prevIdle = idle
                    root.prevTotal = total
                } catch (e) {
                    // keep previous
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: proc.running = true
    }
    Component.onCompleted: proc.running = true
}
