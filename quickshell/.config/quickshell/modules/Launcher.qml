import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

// No rofi: parses .desktop files itself and exec's the match.
PanelWindow {
    id: root
    visible: false
    focusable: true
    anchors { top: true }
    margins.top: 80
    implicitWidth: 480
    implicitHeight: 360
    color: "transparent"

    property var apps: []

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            root.visible = !root.visible;
            if (root.visible) {
                query.text = "";
                query.forceActiveFocus();
                appsProc.running = true;
            }
        }
    }

    function launch(exec) {
        Quickshell.execDetached(["sh", "-c", exec]);
        root.visible = false;
    }

    Process {
        id: appsProc
        // Name + Exec from every .desktop file, tab-separated, one per line.
        command: ["sh", "-c",
            "for f in /usr/share/applications/*.desktop \"$HOME\"/.local/share/applications/*.desktop; do " +
            "[ -f \"$f\" ] || continue; " +
            "name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/%[a-zA-Z]//g'); " +
            "[ -n \"$name\" ] && [ -n \"$exec\" ] && printf '%s\\t%s\\n' \"$name\" \"$exec\"; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.apps = text.split("\n").filter(l => l.length > 0).map(l => {
                    const parts = l.split("\t");
                    return { name: parts[0], exec: parts[1] };
                });
            }
        }
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
                placeholderText: "Run or launch…"
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
                onAccepted: {
                    if (list.model.length > 0) root.launch(list.model[0].exec);
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.apps.filter(a => a.name.toLowerCase().includes(query.text.toLowerCase()))
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 36
                    radius: 6
                    color: index === 0 ? Colors.surface : (hover.hovered ? Qt.darker(Colors.surface, 1.15) : "transparent")
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        color: Colors.foreground
                        text: modelData.name
                    }
                    HoverHandler { id: hover }
                    TapHandler { onTapped: root.launch(modelData.exec) }
                }
            }
        }
    }
}
