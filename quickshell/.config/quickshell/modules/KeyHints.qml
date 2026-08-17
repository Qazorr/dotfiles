import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

// Keybind cheat sheet: reads `hyprctl binds -j`, which includes the
// description text from every `bindd`/`binded`/`bindmd`/... in
// keybindings.conf. Plain `bind` (no description) entries are skipped —
// that's deliberate, it's what keeps this list from being cluttered with
// internal/uninteresting binds.
PanelWindow {
    id: root
    visible: false
    focusable: true
    anchors { top: true }
    margins.top: 60
    implicitWidth: 560
    implicitHeight: 480
    color: "transparent"

    property var binds: []

    IpcHandler {
        target: "keyhints"
        function toggle(): void {
            root.visible = !root.visible;
            if (root.visible) {
                query.text = "";
                query.forceActiveFocus();
                loader.running = true;
            }
        }
    }

    Process {
        id: loader
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(text);
                    root.binds = all
                        .filter(b => b.description && b.description.length > 0)
                        .map(b => {
                            const mods = b.modmask ? hyprModsToString(b.modmask) : "";
                            return { keys: (mods ? mods + " + " : "") + b.key, description: b.description };
                        });
                } catch (e) {
                    console.warn("KeyHints.qml: failed to parse hyprctl binds -j:", e);
                }
            }
        }
    }

    // Hyprland's modmask bitfield: SHIFT=1, CAPS=2, CTRL=4, ALT=8, SUPER=64
    // (mod5/ISO_LEVEL etc. omitted — not used in keybindings.conf).
    function hyprModsToString(mask) {
        const parts = [];
        if (mask & 64) parts.push("SUPER");
        if (mask & 4) parts.push("CTRL");
        if (mask & 8) parts.push("ALT");
        if (mask & 1) parts.push("SHIFT");
        return parts.join(" ");
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Colors.background
        border.color: Colors.surface
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            TextField {
                id: query
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                placeholderText: "Filter keybinds…"
                placeholderTextColor: Colors.surface
                color: Colors.foreground
                font.pixelSize: 15
                leftPadding: 10
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                background: Rectangle {
                    radius: 8
                    color: Colors.surface
                }
                Keys.onEscapePressed: root.visible = false
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.binds.filter(b =>
                    b.description.toLowerCase().includes(query.text.toLowerCase()) ||
                    b.keys.toLowerCase().includes(query.text.toLowerCase()))
                delegate: RowLayout {
                    required property var modelData
                    width: ListView.view.width
                    height: 28
                    Text {
                        Layout.preferredWidth: 200
                        color: Colors.accent2
                        font.family: "monospace"
                        text: modelData.keys
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Colors.foreground
                        text: modelData.description
                    }
                }
            }
        }
    }
}
