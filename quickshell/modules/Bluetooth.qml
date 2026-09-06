// Bluetooth — via bluetoothctl, hides if no adapter
import Quickshell.Io
import QtQuick

Text {
    id: root
    color: "#787c99"
    font.family: "Inter"
    font.pixelSize: 10
    visible: display !== ""
    property string display: ""
    text: display

    Process {
        id: proc
        command: ["sh", "-c", "systemctl is-active bluetooth 2>/dev/null | head -1; bluetoothctl show 2>/dev/null | grep -E 'Powered:' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const lines = text.trim().split("\n")
                    const active = (lines[0] || "").trim() // "active" or "inactive" or ""
                    const poweredLine = (lines[1] || "").trim() // "Powered: yes"
                    if (active !== "active") {
                        root.display = "" // no bluetooth service → hide (valid state per AGENTS §22)
                        return
                    }
                    if (poweredLine.includes("yes")) {
                        root.display = "BT"
                        root.color = "#7dcfff"
                    } else if (poweredLine.includes("no")) {
                        root.display = "BT off"
                        root.color = "#787c99"
                    } else {
                        root.display = "BT"
                        root.color = "#787c99"
                    }
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
