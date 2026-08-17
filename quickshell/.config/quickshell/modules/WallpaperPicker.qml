import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Thumbnail grid of everything in ~/.local/share/wallpapers/ — drop images
// there to add them to the picker, nothing else to configure. Picking one
// runs wallust-apply <path>, which sets it via swww and regenerates the
// palette (Hyprland borders + Quickshell theme) from it.
PanelWindow {
    id: root
    visible: false
    focusable: true
    anchors { top: true }
    margins.top: 60
    implicitWidth: 660
    implicitHeight: 420
    color: "transparent"

    property var wallpapers: []
    property string wallpaperDir: (Quickshell.env("HOME") ?? "/home/kacper") + "/.local/share/wallpapers"
    property string wallustApply: (Quickshell.env("HOME") ?? "/home/kacper") + "/.local/bin/wallust-apply"

    IpcHandler {
        target: "wallpaperpicker"
        function toggle(): void {
            root.visible = !root.visible;
            if (root.visible) lister.running = true;
        }
    }

    Process {
        id: lister
        command: ["sh", "-c",
            "find \"" + root.wallpaperDir + "\" -maxdepth 1 -type f " +
            "\\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) | sort"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.wallpapers = text.split("\n").filter(l => l.length > 0)
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

        GridView {
            id: grid
            anchors.fill: parent
            anchors.margins: 14
            cellWidth: 200
            cellHeight: 130
            clip: true
            model: root.wallpapers
            delegate: Item {
                id: delegateItem
                required property string modelData
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 8
                    color: Colors.surface
                    border.color: hover.hovered ? Colors.accent : "transparent"
                    border.width: 2
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: "file://" + delegateItem.modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    HoverHandler { id: hover }
                    TapHandler {
                        onTapped: {
                            Quickshell.execDetached([root.wallustApply, delegateItem.modelData]);
                            root.visible = false;
                        }
                    }
                }
            }
        }
    }
}
