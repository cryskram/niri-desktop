// Temp — via /sys/class/thermal or sensors, hides if unavailable
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
        command: ["sh", "-c", "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | head -1; echo ---; sensors 2>/dev/null | grep -m1 -E 'Package id 0|Tctl|Core 0' | grep -oE '[0-9]+\\.[0-9]+°C' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.trim().split("\n")
                    let temp = ""
                    for (const p of parts) {
                        const t = p.trim()
                        if (!t || t === "---") continue
                        if (/^\d+$/.test(t)) {
                            // /sys/class/thermal gives millidegrees
                            const v = parseInt(t, 10)
                            if (v > 1000) {
                                temp = Math.round(v / 1000) + "°C"
                                break
                            }
                        } else if (t.includes("°C")) {
                            temp = t
                            break
                        }
                    }
                    if (!temp) {
                        root.display = ""
                        return
                    }
                    const n = parseInt(temp, 10)
                    root.display = `Tmp ${temp}`
                    if (n >= 85) root.color = "#f7768e"
                    else if (n >= 75) root.color = "#e0af68"
                    else root.color = "#c0caf5"
                } catch (e) {
                    root.display = ""
                }
            }
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: proc.running = true
    }
    Component.onCompleted: proc.running = true
}
