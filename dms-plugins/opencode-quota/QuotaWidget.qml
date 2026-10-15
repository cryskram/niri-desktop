import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// OpenCode quota pill — DMS port of the Noctalia luau plugin.
// Data: ~/.cache/opencode-quota.json, kept fresh by the opencode-quota-fetch timer.
// Reset times render in IST (UTC+5:30) like the old panel did.
PluginComponent {
    id: root

    property var usage: ({})

    function pct(key) {
        var entry = root.usage[key];
        return entry && entry.percent !== undefined ? entry.percent : null;
    }

    function resetAt(key) {
        var entry = root.usage[key];
        return entry && entry.resetsAt ? entry.resetsAt : "";
    }

    function pillText() {
        var r = root.pct("rolling");
        var w = root.pct("weekly");
        var m = root.pct("monthly");
        if (r === null && w === null && m === null)
            return "◉ —";
        return "◉ " + (r === null ? 0 : r) + "% · " + (w === null ? 0 : w) + "% · " + (m === null ? 0 : m) + "%";
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    function fmtIst(iso) {
        if (!iso)
            return "—";
        var t = Date.parse(iso);
        if (isNaN(t))
            return "—";
        var d = new Date(t + 5.5 * 3600 * 1000);
        return pad(d.getUTCMonth() + 1) + "/" + pad(d.getUTCDate()) + " " + pad(d.getUTCHours()) + ":" + pad(d.getUTCMinutes()) + " IST";
    }

    function read() {
        quotaFile.running = true;
    }

    Process {
        id: quotaFile
        command: ["cat", "/home/vageesh/.cache/opencode-quota.json"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    root.usage = parsed.usage ? parsed.usage : ({});
                } catch (e) {
                    root.usage = ({});
                }
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.read()
    }

    horizontalBarPill: Component {
        StyledRect {
            width: pillLabel.implicitWidth + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            StyledText {
                id: pillLabel
                anchors.centerIn: parent
                text: root.pillText()
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }

    verticalBarPill: Component {
        StyledRect {
            width: parent.widgetThickness
            height: vertLabel.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            StyledText {
                id: vertLabel
                anchors.centerIn: parent
                text: "◉"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                rotation: 90
            }
        }
    }

    popoutWidth: 340
    popoutHeight: 260

    popoutContent: Component {
        PopoutComponent {
            headerText: "OpenCode quota"
            detailsText: "rolling · weekly · monthly — resets in IST"

            Column {
                width: parent.width
                spacing: Theme.spacingM

                Repeater {
                    model: [
                        {
                            key: "rolling",
                            label: "Rolling"
                        },
                        {
                            key: "weekly",
                            label: "Weekly"
                        },
                        {
                            key: "monthly",
                            label: "Monthly"
                        }
                    ]

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                width: parent.width * 0.3
                                text: modelData.label
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                            }

                            StyledText {
                                text: root.pct(modelData.key) === null ? "—" : root.pct(modelData.key) + "%"
                                color: Theme.primary
                                font.pixelSize: Theme.fontSizeMedium
                            }

                            StyledText {
                                text: root.fmtIst(root.resetAt(modelData.key))
                                color: Theme.surfaceText
                                opacity: 0.6
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }

                        StyledRect {
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Theme.surfaceContainer

                            StyledRect {
                                height: parent.height
                                radius: parent.radius
                                color: Theme.primary
                                width: parent.width * (root.pct(modelData.key) === null ? 0 : Math.min(100, root.pct(modelData.key)) / 100)
                            }
                        }
                    }
                }
            }
        }
    }
}
