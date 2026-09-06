// Battery — via /sys/class/power_supply, hides if no battery (desktop)
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
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null; echo ---; cat /sys/class/power_supply/BAT0/status 2>/dev/null; echo ---; cat /sys/class/power_supply/BAT1/capacity 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.trim().split("\n")
                    // parts: [cap0, ---, status0, ---, cap1]
                    let cap = ""
                    let status = ""
                    for (let i = 0; i < parts.length; i++) {
                        if (parts[i] === "---") continue
                        if (!cap && /^\d+$/.test(parts[i].trim())) cap = parts[i].trim()
                        else if (!status && /^(Charging|Discharging|Full|Not charging)/i.test(parts[i].trim())) status = parts[i].trim()
                    }
                    // fallback to BAT1 if BAT0 missing
                    if (!cap && parts.length > 4) {
                        const alt = parts[parts.length - 1].trim()
                        if (/^\d+$/.test(alt)) cap = alt
                    }
                    if (!cap) {
                        root.display = "" // no battery → hide
                        return
                    }
                    const pct = parseInt(cap, 10)
                    let icon = "Bat"
                    if (status.toLowerCase().includes("charging")) icon = "Chg"
                    else if (status.toLowerCase().includes("full")) icon = "Full"
                    root.display = `${icon} ${pct}%`
                    if (pct < 15 && !status.toLowerCase().includes("charging")) root.color = "#f7768e"
                    else if (pct < 30) root.color = "#e0af68"
                    else root.color = "#c0caf5"
                } catch (e) {
                    root.display = ""
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: proc.running = true
    }
    Component.onCompleted: proc.running = true
}
