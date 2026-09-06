// Power — simple indicator, click for power menu (placeholder per RICE §10)
import QtQuick

Text {
    id: root
    text: "⏻"
    color: "#f7768e"
    font.pixelSize: 12
    font.family: "Inter"

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // For now, just show a notification; real power panel comes in Phase 6
            // Use niri msg or systemctl — placeholder
        }
    }
}
