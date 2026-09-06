// Clock — updates every second, Tokyo Night Storm
import QtQuick

Text {
    id: clock
    color: "#c0caf5"
    font.family: "Inter"
    font.pixelSize: 11
    font.bold: false

    // Updates via Timer
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "hh:mm  •  ddd MMM d")
    }
    Component.onCompleted: text = Qt.formatDateTime(new Date(), "hh:mm  •  ddd MMM d")
}
