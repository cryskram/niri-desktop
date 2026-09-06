// Bar — highly customized r/unixporn floating bar, Tokyo Night Storm
// Floating, blurred, icon-driven, no overflow
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: barRoot
    signal networkClicked()
    signal audioClicked()

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

            // Floating bar — margins create floating effect
            margins {
                top: 8
                left: 12
                right: 12
            }

            implicitHeight: 38
            color: "transparent"

            // Background with blur fallback (transparent → solid per RICE §11)
            Rectangle {
                anchors.fill: parent
                color: "#1a1b26e6" // Storm deep 90%
                radius: 10
                border.width: 1
                border.color: "#3b4261"

                // Subtle inner highlight
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "transparent"
                    border.width: 1
                    border.color: "#24283b"
                    opacity: 0.5
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    // Left — niri + workspaces (pill)
                    RowLayout {
                        Layout.fillWidth: false
                        spacing: 8
                        // Logo / niri
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 22
                            radius: 6
                            color: "#7aa2f7"
                            Text {
                                anchors.centerIn: parent
                                text: "󰣖"
                                color: "#1a1b26"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }
                        }
                        // Workspaces — pill container
                        Rectangle {
                            Layout.preferredHeight: 24
                            radius: 8
                            color: "#24283b"
                            border.width: 1
                            border.color: "#3b4261"
                            Layout.leftMargin: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 4
                                Workspaces {}
                            }
                        }
                    }

                    // Center — window title with app icon (constrained so right side never starves)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 120
                        Layout.preferredWidth: 320
                        Layout.maximumWidth: 520
                        Layout.preferredHeight: 24
                        radius: 8
                        color: "#24283b"
                        border.width: 1
                        border.color: "#292e42"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 6
                            Text {
                                text: "󰣆"
                                color: "#787c99"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                Layout.alignment: Qt.AlignVCenter
                            }
                            WindowTitle {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    // Right — system pills
                    RowLayout {
                        Layout.fillWidth: false
                        spacing: 6

                        // Telemetry pill
                        Rectangle {
                            Layout.preferredHeight: 24
                            radius: 8
                            color: "#24283b"
                            border.width: 1
                            border.color: "#3b4261"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                RowLayout {
                                    spacing: 3
                                    Text { text: ""; color: "#7aa2f7"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                    Cpu {}
                                }
                                Rectangle { width: 1; height: 12; color: "#3b4261" }
                                RowLayout {
                                    spacing: 3
                                    Text { text: ""; color: "#9ece6a"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                    Ram {}
                                }
                                Gpu { visible: text !== "" }
                                Temp { visible: text !== "" }
                            }
                        }

                        // System pill
                        Rectangle {
                            Layout.preferredHeight: 24
                            radius: 8
                            color: "#24283b"
                            border.width: 1
                            border.color: "#3b4261"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                Network {
                                    onClicked: barRoot.networkClicked()
                                }
                                Audio {
                                    onClicked: barRoot.audioClicked()
                                }
                                Media {}
                                Battery {}
                                Bluetooth {}
                                Notifications {}
                            }
                        }

                        // Power + Clock pill
                        RowLayout {
                            spacing: 6
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 24
                                radius: 8
                                color: "#f7768e"
                                Text {
                                    anchors.centerIn: parent
                                    text: "⏻"
                                    color: "#1a1b26"
                                    font.pixelSize: 12
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // wlogout
                                    }
                                }
                            }
                            Rectangle {
                                Layout.preferredHeight: 24
                                radius: 8
                                color: "#292e42"
                                border.width: 1
                                border.color: "#414868"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 6
                                    Text { text: ""; color: "#7aa2f7"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                    Clock {}
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
