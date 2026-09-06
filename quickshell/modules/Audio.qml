// Audio — via wpctl, PipeWire
import Quickshell.Io
import QtQuick
import ".."

Text {
    id: root
    color: "#c0caf5"
    font.family: "Inter"
    font.pixelSize: 10
    property string display: "Vol —"

    text: display

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: State.audioPanelVisible = !State.audioPanelVisible
    }

    Process {
        id: proc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const lines = text.trim().split("\n")
                    const sink = (lines[0] || "").trim() // "Volume: 0.40" or "Volume: 0.40 [MUTED]"
                    const isMuted = sink.includes("MUTED")
                    const m = sink.match(/([0-9.]+)/)
                    if (!m) {
                        root.display = "Vol —"
                        root.color = "#787c99"
                        return
                    }
                    const vol = Math.round(parseFloat(m[1]) * 100)
                    if (isMuted) {
                        root.display = "Muted"
                        root.color = "#f7768e"
                    } else {
                        root.display = `Vol ${vol}%`
                        root.color = vol > 85 ? "#e0af68" : "#c0caf5"
                    }
                } catch (e) {
                    root.display = "Vol —"
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
