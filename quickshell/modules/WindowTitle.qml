// WindowTitle — focused window title via `niri msg -j focused-window`
import Quickshell.Io
import QtQuick

Text {
    id: root
    property string displayTitle: "—"

    text: displayTitle
    elide: Text.ElideRight
    maximumLineCount: 1
    horizontalAlignment: Text.AlignHCenter
    color: "#a9b1d6"
    font.family: "Inter"
    font.pixelSize: 11

    Process {
        id: proc
        command: ["niri", "msg", "-j", "focused-window"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (!text || text.trim() === "null" || text.trim() === "") {
                        root.displayTitle = "—"
                        return
                    }
                    const data = JSON.parse(text)
                    if (!data) {
                        root.displayTitle = "—"
                    } else if (data.title && data.title.trim() !== "") {
                        root.displayTitle = data.title
                    } else if (data.app_id) {
                        root.displayTitle = data.app_id
                    } else {
                        root.displayTitle = "—"
                    }
                } catch (e) {
                    root.displayTitle = "—"
                }
            }
        }
    }

    Timer {
        interval: 600
        running: true
        repeat: true
        onTriggered: proc.running = true
    }
    Component.onCompleted: proc.running = true
}
