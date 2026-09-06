// Bar — top panel, per-screen, Tokyo Night Storm
// Requirements per AGENTS §16 / RICE §9: no overflow, no fixed widths,
// survive long titles / many workspaces / missing services, handle 1920×1080 + future 2nd monitor.
import Quickshell
import QtQuick
import QtQuick.Layouts

Variants {
    model: Quickshell.screens

    PanelWindow {
        property var modelData
        screen: modelData

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 32
        color: "#24283b"

        // Subtle border bottom — Storm border
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#3b4261"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            // Left — placeholder for workspaces (Niri IPC later). For now static.
            RowLayout {
                Layout.fillWidth: false
                spacing: 6
                Text {
                    text: "niri"
                    color: "#7aa2f7"
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.bold: true
                }
                // Placeholder workspace dots
                Repeater {
                    model: 4
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: index === 0 ? "#7aa2f7" : "#3b4261"
                    }
                }
            }

            // Center — window title (truncated, flexible). No fixed width per AGENTS §16.
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                text: "—"
                color: "#a9b1d6"
                font.family: "Inter"
                font.pixelSize: 11
            }

            // Right — clock + system hint
            RowLayout {
                Layout.fillWidth: false
                spacing: 12
                Clock {}
                Text {
                    text: "◷"
                    color: "#787c99"
                    font.pixelSize: 10
                }
            }
        }
    }
}
