import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

// Detail panel for the commute widget (Commute.qml in the bar opens this,
// as does `qs ipc call commute toggle`).
//
// Polls `krk-commute show --direction both --json` only while visible — the
// bar widget already keeps the compact label fresh on its own, and this
// command reads the daemon's cache file rather than the network.
PanelWindow {
    id: root
    visible: false
    focusable: true
    anchors { top: true }
    margins.top: 40
    implicitWidth: 620
    // Size to the content rather than a fixed height: collapsed this is a
    // short summary, expanded it is two full timetables. Capped so a long
    // expansion scrolls (see the Flickable below) instead of running off
    // the bottom of the screen.
    implicitHeight: Math.min(maxHeight, 2 * layout.anchors.margins + header.implicitHeight
        + 2 * layout.spacing + 1 + body.implicitHeight)
    color: "transparent"

    property int maxHeight: 700

    // Keep in sync with Commute.qml's `binary`.
    property string binary: Quickshell.env("HOME") + "/Projects/krk-commute/.venv/bin/krk-commute"
    property int refreshIntervalMs: 20000

    property var bothData: null
    property bool failed: false
    property bool pending: false

    IpcHandler {
        target: "commute"
        function toggle(): void {
            root.visible = !root.visible;
            if (root.visible) root.refresh();
        }
    }

    function refresh() {
        if (proc.running) return;
        pending = true;
        proc.running = true;
    }

    // See Commute.qml: a missing backend never produces a stdout stream, so
    // the "no answer at all" case has to be caught off the process exit.
    function settle() {
        if (!pending) return;
        pending = false;
        failed = true;
        bothData = null;
    }

    Process {
        id: proc
        command: [root.binary, "show", "--direction", "both", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.bothData = JSON.parse(text);
                    root.failed = false;
                } catch (e) {
                    console.warn("CommutePanel.qml: failed to parse krk-commute output:", e);
                    root.bothData = null;
                    root.failed = true;
                }
                root.pending = false;
            }
        }
        onRunningChanged: if (!proc.running) Qt.callLater(root.settle)
    }

    Timer {
        interval: root.refreshIntervalMs
        running: root.visible
        repeat: true
        onTriggered: root.refresh()
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Colors.background
        border.color: Colors.surface
        border.width: 1
        focus: true
        Keys.onEscapePressed: root.visible = false

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                id: header
                Layout.fillWidth: true
                spacing: 8

                Text {
                    color: Colors.accent
                    font.pixelSize: 20
                    text: "\uf238"   // fa-train
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        color: Colors.foreground
                        font.pixelSize: 16
                        font.bold: true
                        text: "Kraków commute"
                    }

                    Text {
                        color: Qt.darker(Colors.foreground, 1.4)
                        font.pixelSize: 11
                        text: {
                            if (root.failed) return "backend unavailable";
                            if (root.bothData && root.bothData.work) {
                                return "updated " + Math.round(root.bothData.work.updated_seconds_ago) + "s ago";
                            }
                            return "waiting for data";
                        }
                    }
                }

                Text {
                    color: refreshHover.hovered ? Colors.accent : Qt.darker(Colors.foreground, 1.4)
                    font.pixelSize: 15
                    text: "\uf021"   // fa-refresh
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler {
                        id: refreshHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler { onTapped: root.refresh() }
                    ToolTip.text: "Refresh"
                    ToolTip.visible: refreshHover.hovered
                    ToolTip.delay: 400
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.surface
            }

            // Expanding the alternatives can easily overflow the window, so
            // the body scrolls rather than growing past the panel edge.
            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                ColumnLayout {
                    id: body
                    width: flick.width
                    spacing: 12

                    // Replaces the two sections entirely when the backend
                    // cannot be reached: two stalled "loading..." lines say
                    // nothing about what is actually wrong.
                    Text {
                        Layout.fillWidth: true
                        visible: root.failed
                        wrapMode: Text.WordWrap
                        color: Colors.urgent
                        text: "Could not run the krk-commute backend.\n\n"
                            + root.binary
                            + "\n\nCheck that it is installed and that "
                            + "krk-commute.service is running."
                    }

                    CommuteChainSection {
                        visible: !root.failed
                        Layout.fillWidth: true
                        title: "Leaving work"
                        chain: root.bothData ? root.bothData.work : null
                    }

                    Rectangle {
                        visible: !root.failed
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Colors.surface
                    }

                    CommuteChainSection {
                        visible: !root.failed
                        Layout.fillWidth: true
                        title: "Leaving home"
                        chain: root.bothData ? root.bothData.home : null
                    }
                }
            }
        }
    }
}
