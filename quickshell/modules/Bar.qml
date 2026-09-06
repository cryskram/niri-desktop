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

            // Left — live workspaces
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
                Workspaces {}
            }

            // Center — live window title (truncated, flexible). No fixed width per AGENTS §16.
            WindowTitle {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            // Right — telemetry + clock (no fixed widths, truncation in center protects this)
            RowLayout {
                Layout.fillWidth: false
                spacing: 10
                Cpu {}
                Ram {}
                // Separator
                Rectangle {
                    width: 1
                    height: 14
                    color: "#3b4261"
                }
                Clock {}
            }
        }
    }
}
