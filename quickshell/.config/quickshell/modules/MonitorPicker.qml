import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Lists profiles from `monitor-switch --list` and applies the chosen one.
PanelWindow {
    id: root
    visible: false
    focusable: true
    anchors { top: true }
    margins.top: 80
    implicitWidth: 240
    implicitHeight: 200
    color: "transparent"

    property var profiles: []
    // Quickshell is launched via exec-once, which doesn't go through
    // .zshrc — ~/.local/bin isn't on PATH, so this needs a full path.
    property string monitorSwitch: (Quickshell.env("HOME") ?? "/home/kacper") + "/.local/bin/monitor-switch"

    IpcHandler {
        target: "monitorpicker"
        function toggle(): void {
            root.visible = !root.visible;
            if (root.visible) lister.running = true;
        }
    }

    Process {
        id: lister
        command: [root.monitorSwitch, "--list"]
        stdout: StdioCollector {
            onStreamFinished: root.profiles = text.split("\n").filter(l => l.length > 0)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Colors.background
        border.color: Colors.surface
        border.width: 1
        focus: true
        Keys.onEscapePressed: root.visible = false

        ListView {
            anchors.fill: parent
            anchors.margins: 10
            clip: true
            model: root.profiles
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 32
                radius: 6
                color: hover.hovered ? Colors.surface : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    color: Colors.foreground
                    text: modelData
                }
                HoverHandler { id: hover }
                TapHandler {
                    onTapped: {
                        Quickshell.execDetached([root.monitorSwitch, modelData]);
                        root.visible = false;
                    }
                }
            }
        }
    }
}
