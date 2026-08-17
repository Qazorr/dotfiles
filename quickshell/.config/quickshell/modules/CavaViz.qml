import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

// Live spectrum bars in the Quickshell bar, driven by cava's raw output
// mode (cava/.config/cava/bar-config — separate from the standalone TUI
// config used by SUPER+ALT+C). Format verified directly against the cava
// binary: one line per frame, semicolon-separated integers 0-7, e.g.
// "0;3;7;2;0;0;1;4;2;0;".
RowLayout {
    id: root
    spacing: 2

    readonly property int barCount: 10
    readonly property int maxLevel: 7
    property var levels: []

    Repeater {
        model: root.barCount
        delegate: Rectangle {
            required property int index
            Layout.alignment: Qt.AlignVCenter
            width: 3
            radius: 1
            color: Colors.accent
            height: Math.max(2, ((root.levels[index] ?? 0) / root.maxLevel) * 18)
            Behavior on height { NumberAnimation { duration: 60 } }
        }
    }

    Process {
        id: cavaProc
        command: ["cava", "-p", (Quickshell.env("HOME") ?? "/home/kacper") + "/.config/cava/bar-config"]
        Component.onCompleted: running = true
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";").filter(s => s.length > 0).map(Number);
                if (parts.length > 0) root.levels = parts;
            }
        }
    }
}
