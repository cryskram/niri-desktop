// niri-desktop — Quickshell root
// Modular bar (RICE §7). Keep shell.qml minimal; Bar owns layout.
import Quickshell
import "modules"
import "modules/panels"

ShellRoot {
    Bar {}
    NetworkPanel {}
    AudioPanel {}
}
