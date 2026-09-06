// Gpu — via intel_gpu_top or /sys/class/drm (best-effort, hides if unavailable)
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
        command: ["sh", "-c", "cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || cat /sys/class/drm/card0/gt_cur_freq_mhz 2>/dev/null | head -1; echo ---; intel_gpu_top -o - 2>/dev/null | head -1 | grep -oE '[0-9]+%' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const t = text.trim()
                    if (!t || t === "---" || t === "") {
                        root.display = "" // no GPU data → hide (per AGENTS §22)
                        return
                    }
                    // Try to parse percent
                    const m = t.match(/([0-9]+)%/)
                    if (m) {
                        const pct = parseInt(m[1], 10)
                        root.display = `GPU ${pct}%`
                        root.color = pct > 85 ? "#f7768e" : "#c0caf5"
                    } else {
                        const n = parseInt(t.split("\n")[0].trim(), 10)
                        if (!isNaN(n) && n > 0) {
                            root.display = `GPU ${n}MHz`
                        } else {
                            root.display = ""
                        }
                    }
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
