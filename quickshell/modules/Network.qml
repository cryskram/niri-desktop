// Network — via nmcli, survives disconnected/unavailable
import Quickshell.Io
import QtQuick
import State 1.0

Text {
    id: root
    color: "#c0caf5"
    font.family: "Inter"
    font.pixelSize: 10
    property string display: "Net —"
    text: display

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: State.networkPanelVisible = !State.networkPanelVisible
    }

    Process {
        id: proc
        command: ["sh", "-c", "nmcli -t -f STATE general 2>/dev/null; nmcli -t -f NAME c show --active 2>/dev/null | head -1 | cut -d: -f1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const lines = text.trim().split("\n")
                    const state = (lines[0] || "").trim()
                    const name = (lines[1] || "").trim()
                    if (state === "connected" && name) {
                        root.display = name.length > 14 ? name.substring(0, 14) + "…" : name
                        root.color = "#c0caf5"
                    } else if (state === "connected") {
                        root.display = "Net"
                        root.color = "#c0caf5"
                    } else if (state === "connecting") {
                        root.display = "Net…"
                        root.color = "#e0af68"
                    } else if (state === "disconnected" || state === "") {
                        root.display = "Net off"
                        root.color = "#787c99"
                    } else {
                        root.display = "Net —"
                        root.color = "#787c99"
                    }
                } catch (e) {
                    root.display = "Net —"
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
