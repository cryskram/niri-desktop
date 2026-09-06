// AudioPanel — floating audio controls (wpctl)
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    visible: false
    implicitWidth: 360
    implicitHeight: 220
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
                text: "Audio"
                color: "#7aa2f7"
                font.family: "Inter"
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                id: volText
                color: "#c0caf5"
                font.family: "Inter"
                font.pixelSize: 11
                text: "Vol —"
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
                        text: "Mute toggle"
                        color: "#c0caf5"
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: muteProc.running = true
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 28
                    height: 28
                    radius: 6
                    color: "#3b4261"
                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        color: "#c0caf5"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: volDownProc.running = true
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 28
                    height: 28
                    radius: 6
                    color: "#3b4261"
                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: "#c0caf5"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: volUpProc.running = true
                    }
                }
            }

            Process {
                id: muteProc
                command: ["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null; sleep 0.2; poll.running = true"]
                stdout: StdioCollector {}
            }
            Process {
                id: volDownProc
                command: ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- 2>/dev/null; poll.running = true"]
                stdout: StdioCollector {}
            }
            Process {
                id: volUpProc
                command: ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0 2>/dev/null; poll.running = true"]
                stdout: StdioCollector {}
            }
        }
    }

    Process {
        id: poll
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const t = text.trim()
                    const m = t.match(/([0-9.]+)/)
                    const muted = t.includes("MUTED")
                    if (!m) {
                        volText.text = "Vol —"
                        return
                    }
                    const pct = Math.round(parseFloat(m[1]) * 100)
                    volText.text = muted ? `Muted (${pct}%)` : `Volume ${pct}%`
                    volText.color = muted ? "#f7768e" : "#c0caf5"
                } catch (e) { volText.text = "Vol —" }
            }
        }
    }

    Timer {
        interval: 1500
        running: root.visible
        repeat: true
        onTriggered: poll.running = true
    }
    onVisibleChanged: if (visible) poll.running = true
}
