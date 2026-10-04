import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root
    property var quota: ({ rolling: 0, weekly: 14, monthly: 23, rollingReset: "", weeklyReset: "", monthlyReset: "" })
    property bool popupVisible: false

    function formatReset(iso) {
        if (!iso) return ""
        let d = new Date(iso)
        let now = new Date()
        let diff = d - now
        if (diff < 0) return "now"
        let h = Math.floor(diff / 3600000)
        let m = Math.floor((diff % 3600000) / 60000)
        if (h > 24) {
            return d.toLocaleDateString(undefined, {month: "short", day: "numeric"}) + " " + d.toLocaleTimeString(undefined, {hour: "2-digit", minute:"2-digit"})
        }
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    function quotaColor(p) {
        if (p > 80) return "#ed8796"
        if (p > 50) return "#eed49f"
        return "#a6da95"
    }

    PanelWindow {
        id: panel
        WlrLayershell.namespace: "opencode-quota"
        anchors { top: true; right: true }
        margins { top: 8; right: 140 }
        exclusiveZone: 0
        color: "transparent"
        implicitWidth: 110
        implicitHeight: popupVisible ? 38 + 160 : 38

        // Pill
        Rectangle {
            id: pill
            width: 100
            height: 28
            radius: 12
            color: "#363a4f"
            opacity: 0.88
            border.width: 0.8
            border.color: "#494d64"
            anchors { top: parent.top; right: parent.right; topMargin: 5; rightMargin: 6 }

            Row {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "◉"; color: quotaColor(quota.rolling); font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: quota.rolling + "%"
                    color: quotaColor(quota.rolling)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "· " + quota.weekly + "% · " + quota.monthly + "%"
                    color: "#a5adcb"
                    font.pixelSize: 9
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.popupVisible = !root.popupVisible
            }
        }

        // Popup card
        Rectangle {
            id: popup
            visible: root.popupVisible
            width: 280
            height: 150
            radius: 12
            color: "#24273a"
            opacity: 0.92
            border.width: 0.8
            border.color: "#494d64"
            anchors { top: pill.bottom; right: parent.right; topMargin: 8; rightMargin: 6 }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "OpenCode  ·  opencode-go"
                    color: "#cad3f5"
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                // Rolling
                Column {
                    Layout.fillWidth: true
                    spacing: 4
                    Row {
                        width: parent.width
                        Text { text: "Rolling"; color: "#c6a0f6"; font.pixelSize: 10; font.bold: true; width: 60 }
                        Text { text: quota.rolling + "%"; color: quotaColor(quota.rolling); font.pixelSize: 10; font.bold: true }
                        Item { width: parent.width - 60 - 40 - 80; height: 1 }
                        Text { text: formatReset(quota.rollingReset); color: "#6e738d"; font.pixelSize: 9; horizontalAlignment: Text.AlignRight; width: 80 }
                    }
                    Rectangle {
                        width: parent.width; height: 6; radius: 3; color: "#363a4f"
                        Rectangle { width: parent.width * quota.rolling / 100; height: parent.height; radius: 3; color: quotaColor(quota.rolling) }
                    }
                }
                // Weekly
                Column {
                    Layout.fillWidth: true
                    spacing: 4
                    Row {
                        width: parent.width
                        Text { text: "Weekly"; color: "#8aadf4"; font.pixelSize: 10; font.bold: true; width: 60 }
                        Text { text: quota.weekly + "%"; color: quotaColor(quota.weekly); font.pixelSize: 10; font.bold: true }
                        Item { width: parent.width - 60 - 40 - 80; height: 1 }
                        Text { text: formatReset(quota.weeklyReset); color: "#6e738d"; font.pixelSize: 9; horizontalAlignment: Text.AlignRight; width: 80 }
                    }
                    Rectangle {
                        width: parent.width; height: 6; radius: 3; color: "#363a4f"
                        Rectangle { width: parent.width * quota.weekly / 100; height: parent.height; radius: 3; color: quotaColor(quota.weekly) }
                    }
                }
                // Monthly
                Column {
                    Layout.fillWidth: true
                    spacing: 4
                    Row {
                        width: parent.width
                        Text { text: "Monthly"; color: "#8bd5ca"; font.pixelSize: 10; font.bold: true; width: 60 }
                        Text { text: quota.monthly + "%"; color: quotaColor(quota.monthly); font.pixelSize: 10; font.bold: true }
                        Item { width: parent.width - 60 - 40 - 80; height: 1 }
                        Text { text: formatReset(quota.monthlyReset); color: "#6e738d"; font.pixelSize: 9; horizontalAlignment: Text.AlignRight; width: 80 }
                    }
                    Rectangle {
                        width: parent.width; height: 6; radius: 3; color: "#363a4f"
                        Rectangle { width: parent.width * quota.monthly / 100; height: parent.height; radius: 3; color: quotaColor(quota.monthly) }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {} // block click-through
            }
        }
    }

    // Fetch from cache file (updated by systemd timer)
    Process {
        id: fetcher
        command: ["sh", "-c", "cat ~/.cache/opencode-quota.json 2>/dev/null || echo '{\"usage\":{\"rolling\":{\"percent\":0,\"resetsAt\":\"\"},\"weekly\":{\"percent\":14,\"resetsAt\":\"\"},\"monthly\":{\"percent\":23,\"resetsAt\":\"\"}}}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(text)
                    if (d.usage) root.quota = {
                        rolling: d.usage.rolling.percent,
                        weekly: d.usage.weekly.percent,
                        monthly: d.usage.monthly.percent,
                        rollingReset: d.usage.rolling.resetsAt,
                        weeklyReset: d.usage.weekly.resetsAt,
                        monthlyReset: d.usage.monthly.resetsAt
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: fetcher.running = true
    }

    // Also fetch on popup open
    Connections {
        target: root
        function onPopupVisibleChanged() { if (root.popupVisible) fetcher.running = true }
    }
}
