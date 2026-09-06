// Media — via playerctl, hides when no player (per AGENTS §22)
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Text {
    id: root
    visible: display !== ""
    property string display: ""
    text: display
    elide: Text.ElideRight
    maximumLineCount: 1
    color: "#bb9af7"
    font.family: "Inter"
    font.pixelSize: 10
    // Constrain width so long titles don't overflow the bar
    Layout.maximumWidth: 220

    Process {
        id: proc
        command: ["sh", "-c", "playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null | head -c 60; echo \"---\"; playerctl status 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.trim().split("\n")
                    // first line is "artist - title" or empty, second is status
                    let title = ""
                    let status = ""
                    // text is like "artist - title\n---\nPlaying\n"
                    const raw = text
                    const sepIdx = raw.indexOf("---")
                    if (sepIdx !== -1) {
                        title = raw.substring(0, sepIdx).trim()
                        const after = raw.substring(sepIdx + 3).trim().split("\n")
                        status = (after[0] || "").trim().toLowerCase()
                    } else {
                        title = raw.trim()
                    }
                    if (!title || title === "No players found" || title === "-") {
                        root.display = ""
                        return
                    }
                    // Truncate long titles
                    if (title.length > 32) title = title.substring(0, 32) + "…"
                    const icon = status === "playing" ? "▶" : status === "paused" ? "⏸" : "♫"
                    root.display = `${icon} ${title}`
                } catch (e) {
                    root.display = ""
                }
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

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            toggleProc.running = true
        }
    }
    Process {
        id: toggleProc
        command: ["sh", "-c", "playerctl play-pause 2>/dev/null"]
        stdout: StdioCollector {}
    }
}
