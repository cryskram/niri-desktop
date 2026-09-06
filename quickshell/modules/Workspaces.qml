// Workspaces — live Niri workspaces via `niri msg -j workspaces`
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: 4

    property var workspaces: []

    Process {
        id: proc
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (Array.isArray(data))
                        root.workspaces = data.slice().sort((a, b) => a.idx - b.idx)
                } catch (e) {
                    // keep previous
                }
            }
        }
    }

    Timer {
        interval: 800
        running: true
        repeat: true
        onTriggered: proc.running = true
    }
    Component.onCompleted: proc.running = true

    Repeater {
        model: root.workspaces
        Rectangle {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 18
            radius: 4
            color: modelData.is_active ? "#7aa2f7" : modelData.is_focused ? "#414868" : "#292e42"
            border.width: modelData.is_urgent ? 1 : 0
            border.color: "#f7768e"

            Text {
                anchors.centerIn: parent
                text: modelData.idx
                color: modelData.is_active ? "#1d202f" : modelData.is_urgent ? "#f7768e" : "#c0caf5"
                font.family: "Inter"
                font.pixelSize: 10
                font.bold: modelData.is_active
            }

            // Click to focus workspace — uses niri msg action
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // niri msg action focus-workspace <idx>
                    focusProc.command = ["niri", "msg", "action", "focus-workspace", String(modelData.idx)]
                    focusProc.running = true
                }
            }

            Process {
                id: focusProc
                stdout: StdioCollector {}
            }
        }
    }
}
