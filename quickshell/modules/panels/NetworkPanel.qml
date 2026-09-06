// NetworkPanel — floating network controls (nmcli)
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    visible: false
    implicitWidth: 360
    implicitHeight: 280
    color: "transparent"
    anchors { top: true; right: true }
    margins { top: 40; right: 12 }

    Rectangle {
        anchors.fill: parent
        color: "#292e42f2"
        radius: 12
        border.width: 1
        border.color: "#3b4261"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: "Network"
                color: "#7aa2f7"
                font.family: "Inter"
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                id: statusText
                color: "#c0caf5"
                font.family: "Inter"
                font.pixelSize: 11
                text: "Loading…"
            }

            // List of available networks (simplified)
            ColumnLayout {
                id: list
                spacing: 6
                // Filled via Process
            }

            RowLayout {
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    height: 28
                    radius: 6
                    color: "#3b4261"
                    Text {
                        anchors.centerIn: parent
                        text: "Open nmtui"
                        color: "#c0caf5"
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: procNmtui.running = true
                    }
                }
            }

            Process {
                id: procNmtui
                command: ["sh", "-c", "alacritty -e nmtui 2>/dev/null &"]
                stdout: StdioCollector {}
            }
        }
    }

    // Poll nmcli
    Process {
        id: poll
        command: ["sh", "-c", "nmcli -t -f STATE general 2>/dev/null | head -1; echo ---; nmcli device status 2>&1 | head -10"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.trim().split("\n")
                    let state = ""
                    for (const l of parts) {
                        if (l.includes("connected") || l.includes("disconnected") || l === "---") {
                            if (l !== "---" && l.trim() !== "") state = l.trim()
                        }
                    }
                    const st = (parts[0] || "").trim()
                    if (st === "connected") statusText.text = "Connected — " + (parts[2] || "").trim().split(/\s+/)[0]
                    else if (st === "disconnected") statusText.text = "Disconnected"
                    else statusText.text = st || "Unknown"
                } catch (e) { statusText.text = "—" }
            }
        }
    }

    Timer {
        interval: 3000
        running: root.visible
        repeat: true
        onTriggered: poll.running = true
    }
    onVisibleChanged: if (visible) poll.running = true
}
