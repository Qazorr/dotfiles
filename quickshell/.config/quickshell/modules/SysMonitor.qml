import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../theme"

RowLayout {
    id: root
    spacing: 4

    property real cpuPct: 0
    property real memPct: 0

    Rectangle {
        Layout.preferredWidth: cpuText.implicitWidth + 10
        Layout.preferredHeight: 24
        radius: 4
        color: cpuHover.hovered ? Colors.surface : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        Text { id: cpuText; anchors.centerIn: parent; color: "#f9e2af"; text: "CPU " + root.cpuPct.toFixed(0) + "%" }
        HoverHandler { id: cpuHover }
        ToolTip.text: "CPU usage: " + root.cpuPct.toFixed(0) + "%"
        ToolTip.visible: cpuHover.hovered
        ToolTip.delay: 400
    }

    Rectangle {
        Layout.preferredWidth: memText.implicitWidth + 10
        Layout.preferredHeight: 24
        radius: 4
        color: memHover.hovered ? Colors.surface : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        Text { id: memText; anchors.centerIn: parent; color: "#a6e3a1"; text: "MEM " + root.memPct.toFixed(0) + "%" }
        HoverHandler { id: memHover }
        ToolTip.text: "Memory used: " + root.memPct.toFixed(0) + "%"
        ToolTip.visible: memHover.hovered
        ToolTip.delay: 400
    }

    Process {
        id: sampler
        command: ["sh", "-c",
            "read -r _ a b c d _ < /proc/stat; t1=$((a+b+c+d)); i1=$d; " +
            "sleep 1; " +
            "read -r _ a b c d _ < /proc/stat; t2=$((a+b+c+d)); i2=$d; " +
            "awk -v t1=\"$t1\" -v t2=\"$t2\" -v i1=\"$i1\" -v i2=\"$i2\" 'BEGIN{printf \"%.0f\\n\", (1-(i2-i1)/(t2-t1))*100}'; " +
            "free | awk '/Mem:/{printf \"%.0f\\n\", $3/$2*100}'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length >= 2) {
                    root.cpuPct = parseFloat(lines[0]) || 0;
                    root.memPct = parseFloat(lines[1]) || 0;
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sampler.running = true
    }
}
