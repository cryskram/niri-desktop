// Panel — shared floating panel base (RICE §10)
// Storm surface, 12px radius, 1px border, subtle transparency, blur fallback per §11
import Quickshell
import QtQuick

PanelWindow {
    id: root
    default property alias content: inner.data
    // Override in instances: anchors, margins, screen
    implicitWidth: 360
    implicitHeight: 280
    color: "transparent"
    // Hidden by default — toggled via bar
    visible: false

    Rectangle {
        anchors.fill: parent
        color: "#292e42f2" // Storm surface 95% — blur → transparency → solid fallback
        radius: 12
        border.width: 1
        border.color: "#3b4261"

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: 16
        }
    }
}
