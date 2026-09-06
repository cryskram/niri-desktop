// niri-desktop — Quickshell root
// Modular bar (RICE §7). Keep shell.qml minimal; Bar owns layout.
import Quickshell
import "modules"
import "modules/panels"

ShellRoot {
    id: shellRoot
    property bool networkPanelVisible: false
    property bool audioPanelVisible: false

    Bar {
        onNetworkClicked: shellRoot.networkPanelVisible = !shellRoot.networkPanelVisible
        onAudioClicked: shellRoot.audioPanelVisible = !shellRoot.audioPanelVisible
    }
    NetworkPanel {
        visible: shellRoot.networkPanelVisible
    }
    AudioPanel {
        visible: shellRoot.audioPanelVisible
    }
}
